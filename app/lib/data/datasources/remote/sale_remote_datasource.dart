import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sale_item.dart';

abstract class SaleRemoteDatasource {
  Future<Sale> createSale(String storeId, Map<String, dynamic> data);

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
  });

  Future<Sale> getSale(String storeId, String id);
  Future<Sale> refundSale(String storeId, String id, Map<String, dynamic> data);
}

class SaleRemoteDatasourceImpl implements SaleRemoteDatasource {
  final DioClient _dioClient;

  SaleRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<Sale> createSale(String storeId, Map<String, dynamic> data) async {
    try {
      // Strip offline-only metadata. The API runs forbidNonWhitelisted=true
      // and would 400 on any `_offline*` field that leaked through.
      final apiPayload = Map<String, dynamic>.from(data)
        ..removeWhere((k, _) => k.startsWith('_offline'));
      final response = await _dioClient.post(
        ApiEndpoints.sales(storeId),
        data: apiPayload,
      );
      return _mapSale(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
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
      final response = await _dioClient.get(
        ApiEndpoints.sales(storeId),
        queryParameters: {
          'page': page,
          'limit': limit,
          'customerId': ?customerId,
          'status': ?status,
          'paymentType': ?paymentType,
          if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
          if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
        },
      );

      final responseData = response.data as Map<String, dynamic>;

      // BUG #28: parse each row independently. ONE malformed row (e.g. an
      // unexpected null in a required field) used to blow up the whole
      // list. Now we skip-and-warn so the rest of the page still renders.
      final raw = responseData['data'] as List;
      final list = <Sale>[];
      int skipped = 0;
      for (final entry in raw) {
        try {
          list.add(_mapSale(entry as Map<String, dynamic>));
        } catch (e, st) {
          skipped++;
          debugPrint('SaleRemoteDatasource: skipped malformed row: $e');
          debugPrint(
              '  row keys: ${(entry is Map) ? entry.keys.toList() : entry.runtimeType}');
          debugPrint('  stack: $st');
        }
      }

      return (
        data: list,
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
        skippedRows: skipped,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Sale> getSale(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.sale(storeId, id),
      );
      return _mapSale(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Sale> refundSale(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.saleRefund(storeId, id),
        data: data,
      );
      return _mapSale(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Sale _mapSale(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    return Sale(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String? ??
          (json['customer'] is Map
              ? (json['customer'] as Map<String, dynamic>)['name'] as String?
              : null),
      staffId: json['staffId'] as String?,
      shiftId: json['shiftId'] as String?,
      receiptNo: json['receiptNo'] as String,
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountType: json['discountType'] as String?,
      total: (json['total'] as num).toDouble(),
      paymentType: json['paymentType'] as String,
      paidAmount: (json['paidAmount'] as num).toDouble(),
      change: (json['change'] as num?)?.toDouble() ?? 0,
      debtAmount: (json['debtAmount'] as num?)?.toDouble() ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      status: json['status'] as String? ?? 'COMPLETED',
      notes: json['notes'] as String?,
      items: itemsList
          .map((item) => _mapSaleItem(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  SaleItem _mapSaleItem(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as String,
      saleId: json['saleId'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String? ??
          (json['product'] is Map
              ? (json['product'] as Map<String, dynamic>)['name'] as String? ??
                  ''
              : ''),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
    );
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = e.response?.statusCode;
    final rawMessage = (e.response?.data is Map) ? e.response?.data['message'] : null;
    final String message;
    if (rawMessage is List) {
      message = rawMessage.join(', ');
    } else if (rawMessage is String) {
      message = rawMessage;
    } else {
      message = e.message ?? 'Unknown error';
    }

    if (statusCode == 401) {
      return UnauthorizedException(message);
    }

    return ServerException(message, statusCode: statusCode);
  }
}
