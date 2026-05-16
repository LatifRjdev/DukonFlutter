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
  bool _disposed = false;

  /// Stream controller to broadcast sync status updates.
  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  /// Returns the delay before the next retry, based on how many retries
  /// have already happened. 1st retry: 2s, 2nd: 4s, 3rd: 8s, 4th: 16s,
  /// 5th: 32s, clamped to 60s.
  Duration _backoffFor(int retryCount) {
    final seconds = (1 << retryCount).clamp(1, 60);
    return Duration(seconds: seconds);
  }

  SyncEngine({
    required SyncQueue syncQueue,
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    this.conflictResolver = const ConflictResolver(),
  })  : _syncQueue = syncQueue,
        _dioClient = dioClient,
        _networkInfo = networkInfo;

  /// Start listening for connectivity changes.
  ///
  /// Idempotent — calling `start()` after an existing subscription is active
  /// is a no-op, so wiring this into both app startup and lifecycle hooks is
  /// safe.
  void start() {
    if (_disposed) return;
    if (_connectivitySubscription != null) return;
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (isConnected) {
          processQueue();
        }
      },
    );
  }

  /// Stop listening and clean up.
  ///
  /// Idempotent — safe to call multiple times (e.g. from both
  /// `AppLifecycleState.detached` and `State.dispose()`).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _syncStatusController.close();
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
          // Gate the next retry with exponential backoff so a connectivity
          // flap doesn't hammer the server with simultaneous re-queues.
          // 1st retry: 2s, 2nd: 4s, 3rd: 8s, 4th: 16s, 5th: 32s (capped 60s).
          final delay = _backoffFor(item.retryCount + 1);
          await Future.delayed(delay);
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

      // E.1: shift open via /shifts/open. Offline-replay sends the
      // localId in the payload so the server returns the existing
      // shift on retry. CLOSE intentionally not queued — close-shift
      // happens at end of day which generally has connectivity.
      case 'shift':
        final storeId = parts[0];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.shiftOpen(storeId);
        }
        return null;

      // B.E.2: stock movements. entityId format =
      // `storeId:productId:tempId`.
      case 'stock_movement':
        if (parts.length < 3) return null;
        final storeId = parts[0];
        final productId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.stockMovements(storeId, productId);
        }
        return null;

      // E.3: debt payments. entityId format =
      // `storeId:customerId:localId`. Server idempotency dedupes by
      // localId so retry after partial-success is safe.
      case 'debt_payment':
        if (parts.length < 2) return null;
        final storeId = parts[0];
        final customerId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.customerPayments(storeId, customerId);
        }
        return null;

      // B.E.3: supplier debt payments. entityId format =
      // `storeId:supplierId:tempId`.
      case 'supplier_debt_payment':
        if (parts.length < 3) return null;
        final storeId = parts[0];
        final supplierId = parts[1];
        if (item.operation == 'CREATE') {
          return ApiEndpoints.supplierPayments(storeId, supplierId);
        }
        return null;

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
