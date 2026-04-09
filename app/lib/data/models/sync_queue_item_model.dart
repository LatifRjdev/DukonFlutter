class SyncQueueItemModel {
  final int? id;
  final String tableName;
  final String recordId;
  final String action;
  final String payload;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;

  const SyncQueueItemModel({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
  });

  // --- JSON (API) ---

  factory SyncQueueItemModel.fromJson(Map<String, dynamic> json) {
    return SyncQueueItemModel(
      id: json['id'] as int?,
      tableName: json['tableName'] as String,
      recordId: json['recordId'] as String,
      action: json['action'] as String,
      payload: json['payload'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableName': tableName,
      'recordId': recordId,
      'action': action,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  // --- SQLite Map ---

  factory SyncQueueItemModel.fromMap(Map<String, dynamic> map) {
    return SyncQueueItemModel(
      id: map['id'] as int?,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      action: map['action'] as String,
      payload: map['payload'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'retry_count': retryCount,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}
