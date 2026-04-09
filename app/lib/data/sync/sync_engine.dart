import 'dart:async';
import 'dart:convert';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../core/constants/api_endpoints.dart';
import 'sync_queue.dart';
import 'conflict_resolver.dart';

/// SyncEngine processes queued offline operations when connectivity is restored.
///
/// It listens to network connectivity changes and automatically processes the
/// sync queue when the device comes back online. Operations are processed in
/// FIFO order with retry support.
class SyncEngine {
  final SyncQueue _syncQueue;
  final DioClient _dioClient;
  final NetworkInfo _networkInfo;
  final ConflictResolver conflictResolver;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Stream controller to broadcast sync status updates.
  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  SyncEngine({
    required SyncQueue syncQueue,
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    this.conflictResolver = const ConflictResolver(),
  })  : _syncQueue = syncQueue,
        _dioClient = dioClient,
        _networkInfo = networkInfo;

  /// Start listening for connectivity changes.
  void start() {
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (isConnected) {
          processQueue();
        }
      },
    );
  }

  /// Stop listening and clean up.
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }

  /// Manually trigger sync queue processing.
  Future<void> processQueue() async {
    if (_isSyncing) return;

    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) return;

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      final pendingItems = await _syncQueue.getPendingItems();

      if (pendingItems.isEmpty) {
        _syncStatusController.add(SyncStatus.idle);
        _isSyncing = false;
        return;
      }

      int failCount = 0;

      for (final item in pendingItems) {
        if (item.id == null) continue;

        await _syncQueue.markProcessing(item.id!);

        try {
          await _processItem(item);
          await _syncQueue.markCompleted(item.id!);
        } catch (e) {
          await _syncQueue.markFailed(item.id!);
          failCount++;
        }
      }

      // Clean up items that exceeded max retries
      await _syncQueue.cleanup();

      if (failCount > 0) {
        _syncStatusController.add(SyncStatus.error);
      } else {
        _syncStatusController.add(SyncStatus.completed);
      }
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Get the number of pending sync operations.
  Future<int> pendingCount() => _syncQueue.pendingCount();

  Future<void> _processItem(SyncQueueItem item) async {
    final payload = item.payload != null
        ? jsonDecode(item.payload!) as Map<String, dynamic>
        : <String, dynamic>{};

    final endpoint = _resolveEndpoint(item);
    if (endpoint == null) {
      throw Exception('Cannot resolve endpoint for ${item.entityType}');
    }

    switch (item.operation) {
      case 'CREATE':
        await _dioClient.post(endpoint, data: payload);
        break;
      case 'UPDATE':
        await _dioClient.put(endpoint, data: payload);
        break;
      case 'DELETE':
        await _dioClient.delete(endpoint);
        break;
      default:
        throw Exception('Unknown sync operation: ${item.operation}');
    }
  }

  /// Resolve the API endpoint for a given sync queue item.
  ///
  /// The [entityId] may contain composite identifiers separated by `:`.
  /// For example, `storeId:productId` for products.
  String? _resolveEndpoint(SyncQueueItem item) {
    final parts = item.entityId.split(':');

    switch (item.entityType) {
      case 'product':
        if (parts.length < 2) return null;
        final storeId = parts[0];
        final productId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.products(storeId);
        }
        return ApiEndpoints.product(storeId, productId);

      case 'sale':
        if (parts.length < 2) return null;
        final storeId = parts[0];
        final saleId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.sales(storeId);
        }
        return ApiEndpoints.sale(storeId, saleId);

      case 'category':
        if (parts.length < 2) return null;
        final storeId = parts[0];
        final categoryId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.categories(storeId);
        }
        return ApiEndpoints.category(storeId, categoryId);

      case 'customer':
        if (parts.length < 2) return null;
        final storeId = parts[0];
        final customerId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.customers(storeId);
        }
        return ApiEndpoints.customer(storeId, customerId);

      case 'supplier':
        if (parts.length < 2) return null;
        final storeId = parts[0];
        final supplierId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.suppliers(storeId);
        }
        return ApiEndpoints.supplier(storeId, supplierId);

      case 'store':
        if (item.operation == 'CREATE') {
          return ApiEndpoints.stores;
        }
        return ApiEndpoints.store(parts[0]);

      default:
        return null;
    }
  }
}

enum SyncStatus {
  idle,
  syncing,
  completed,
  error,
}
