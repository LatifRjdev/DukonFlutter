import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/exceptions.dart';

/// Represents a single pending sync operation.
class SyncQueueItem {
  final int? id;
  final String entityType;
  final String entityId;
  final String operation; // CREATE, UPDATE, DELETE
  final String? payload;
  final int retryCount;
  final String status; // PENDING, PROCESSING, FAILED
  final DateTime createdAt;

  const SyncQueueItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload,
    this.retryCount = 0,
    this.status = 'PENDING',
    required this.createdAt,
  });

  SyncQueueItem copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? payload,
    int? retryCount,
    String? status,
    DateTime? createdAt,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Manages a queue of operations to be synced when connectivity is restored.
class SyncQueue {
  final Database _db;

  static const _tableName = 'sync_queue';
  static const int maxRetries = 5;

  SyncQueue({required Database database}) : _db = database;

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON $_tableName (status)',
    );
  }

  /// Enqueue a new sync operation.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    try {
      // If there's already a pending operation for the same entity, update it
      final existing = await _db.query(
        _tableName,
        where: 'entity_type = ? AND entity_id = ? AND status = ?',
        whereArgs: [entityType, entityId, 'PENDING'],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // If we're deleting, remove any previous pending creates/updates
        if (operation == 'DELETE') {
          final previousOp = existing.first['operation'] as String;
          if (previousOp == 'CREATE') {
            // If the entity was created offline and now deleted, just remove
            // the queue entry entirely.
            await _db.delete(
              _tableName,
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
            return;
          }
        }
        // Update the existing entry with the new operation / payload
        await _db.update(
          _tableName,
          {
            'operation': operation,
            'payload': payload != null ? jsonEncode(payload) : null,
            'retry_count': 0,
            'status': 'PENDING',
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await _db.insert(_tableName, {
          'entity_type': entityType,
          'entity_id': entityId,
          'operation': operation,
          'payload': payload != null ? jsonEncode(payload) : null,
          'retry_count': 0,
          'status': 'PENDING',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw CacheException('Failed to enqueue sync operation: $e');
    }
  }

  /// Get all pending items ordered by creation time.
  Future<List<SyncQueueItem>> getPendingItems() async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'status = ? AND retry_count < ?',
        whereArgs: ['PENDING', maxRetries],
        orderBy: 'created_at ASC',
      );
      return rows.map(_mapRow).toList();
    } catch (e) {
      throw CacheException('Failed to get pending sync items: $e');
    }
  }

  /// Mark an item as processing.
  Future<void> markProcessing(int id) async {
    await _db.update(
      _tableName,
      {'status': 'PROCESSING'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove a successfully synced item.
  Future<void> markCompleted(int id) async {
    await _db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Mark an item as failed, incrementing the retry count.
  Future<void> markFailed(int id) async {
    await _db.rawUpdate(
      'UPDATE $_tableName SET status = ?, retry_count = retry_count + 1 WHERE id = ?',
      ['PENDING', id],
    );
  }

  /// Get the number of pending items.
  Future<int> pendingCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE status IN (?, ?)',
      ['PENDING', 'PROCESSING'],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Remove all completed or excessively retried items.
  Future<void> cleanup() async {
    await _db.delete(
      _tableName,
      where: 'retry_count >= ?',
      whereArgs: [maxRetries],
    );
  }

  SyncQueueItem _mapRow(Map<String, dynamic> row) {
    return SyncQueueItem(
      id: row['id'] as int?,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      operation: row['operation'] as String,
      payload: row['payload'] as String?,
      retryCount: row['retry_count'] as int? ?? 0,
      status: row['status'] as String? ?? 'PENDING',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
