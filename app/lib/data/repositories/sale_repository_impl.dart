import '../../core/errors/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/local/sale_local_datasource.dart';
import '../datasources/remote/sale_remote_datasource.dart';
import '../sync/sync_queue.dart';

class SaleRepositoryImpl implements SaleRepository {
  final SaleRemoteDatasource _remoteDatasource;
  final SaleLocalDatasource _localDatasource;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  SaleRepositoryImpl({
    required SaleRemoteDatasource remoteDatasource,
    required SaleLocalDatasource localDatasource,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<Sale> createSale(String storeId, Map<String, dynamic> data) async {
    try {
      if (await _networkInfo.isConnected) {
        final sale = await _remoteDatasource.createSale(storeId, data);
        await _localDatasource.saveSale(sale);
        return sale;
      } else {
        return await _createSaleOffline(storeId, data);
      }
    } on NetworkException {
      return await _createSaleOffline(storeId, data);
    }
  }

  @override
  Future<({List<Sale> data, int total, int totalPages, int skippedRows})>
      getSales(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? customerId,
    String? status,
    String? paymentType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      if (await _networkInfo.isConnected) {
        final result = await _remoteDatasource.getSales(
          storeId,
          page: page,
          limit: limit,
          customerId: customerId,
          status: status,
          paymentType: paymentType,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        // Cache first page for offline access
        if (page == 1 &&
            customerId == null &&
            status == null &&
            paymentType == null) {
          await _localDatasource.saveSales(result.data);
        }

        return result;
      } else {
        final localSales = await _localDatasource.getSales(storeId);
        return (
          data: localSales,
          total: localSales.length,
          totalPages: 1,
          skippedRows: 0,
        );
      }
    } on NetworkException {
      final localSales = await _localDatasource.getSales(storeId);
      return (
        data: localSales,
        total: localSales.length,
        totalPages: 1,
        skippedRows: 0,
      );
    }
  }

  @override
  Future<Sale> getSale(String storeId, String id) async {
    try {
      if (await _networkInfo.isConnected) {
        final sale = await _remoteDatasource.getSale(storeId, id);
        await _localDatasource.saveSale(sale);
        return sale;
      } else {
        final localSale = await _localDatasource.getSale(id);
        if (localSale != null) return localSale;
        throw const CacheException('Sale not found in local storage');
      }
    } on NetworkException {
      final localSale = await _localDatasource.getSale(id);
      if (localSale != null) return localSale;
      throw const CacheException('Sale not found in local storage');
    }
  }

  @override
  Future<Sale> refundSale(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final sale =
            await _remoteDatasource.refundSale(storeId, id, data);
        await _localDatasource.saveSale(sale);
        return sale;
      } else {
        // Refunds require server; enqueue for later processing
        await _syncQueue.enqueue(
          entityType: 'sale',
          entityId: '$storeId:$id',
          operation: 'UPDATE',
          payload: {'action': 'refund', ...data},
        );
        final localSale = await _localDatasource.getSale(id);
        if (localSale != null) return localSale;
        throw const CacheException('Sale not found in local storage');
      }
    } on NetworkException {
      await _syncQueue.enqueue(
        entityType: 'sale',
        entityId: '$storeId:$id',
        operation: 'UPDATE',
        payload: {'action': 'refund', ...data},
      );
      final localSale = await _localDatasource.getSale(id);
      if (localSale != null) return localSale;
      throw const CacheException('Sale not found in local storage');
    }
  }

  @override
  Future<List<Sale>> getLocalSales(String storeId) async {
    return await _localDatasource.getSales(storeId);
  }

  @override
  Future<void> saveSaleLocally(Sale sale) async {
    await _localDatasource.saveSale(sale);
  }

  Future<Sale> _createSaleOffline(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final occurredAtIso = data['occurredAt'] as String?;
    final occurredAt =
        occurredAtIso != null ? DateTime.parse(occurredAtIso).toLocal() : DateTime.now();

    // Computed totals come from CheckoutBloc as `_offline*` keys; the API
    // payload (without them) has only items/discount/paidAmount, so without
    // these we'd persist a Sale with total=0 and the success screen would
    // show "0 TJS" until the next online refresh.
    final subtotal = (data['_offlineSubtotal'] as num?)?.toDouble() ?? 0;
    final total = (data['_offlineTotal'] as num?)?.toDouble() ?? 0;
    final change = (data['_offlineChange'] as num?)?.toDouble() ?? 0;
    final debt = (data['_offlineDebt'] as num?)?.toDouble() ?? 0;

    final sale = Sale(
      id: tempId,
      storeId: storeId,
      customerId: data['customerId'] as String?,
      receiptNo: 'OFF-${occurredAt.millisecondsSinceEpoch}',
      subtotal: subtotal,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      discountType: data['discountType'] as String?,
      total: total,
      paymentType: data['paymentType'] as String? ?? 'CASH',
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      change: change,
      debtAmount: debt,
      notes: data['notes'] as String?,
      createdAt: occurredAt,
    );

    await _localDatasource.saveSale(sale);

    // Drop the _offline* metadata before queueing — those keys would be
    // rejected by the API on replay (forbidNonWhitelisted).
    final apiPayload = Map<String, dynamic>.from(data)
      ..removeWhere((k, _) => k.startsWith('_offline'));

    await _syncQueue.enqueue(
      entityType: 'sale',
      entityId: '$storeId:$tempId',
      operation: 'CREATE',
      payload: apiPayload,
    );

    return sale;
  }
}
