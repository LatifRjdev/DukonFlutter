import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/zakat_calculation.dart';
import '../../../domain/entities/zakat_settings.dart';
import '../../../domain/entities/zakat_payment.dart';

abstract class ZakatRemoteDatasource {
  Future<ZakatCalculation> calculate(String storeId);
  Future<ZakatSettings?> getSettings(String storeId);
  Future<ZakatSettings> upsertSettings(String storeId, Map<String, dynamic> data);
  Future<List<ZakatPayment>> getPayments(String storeId);
  Future<ZakatPayment> createPayment(String storeId, Map<String, dynamic> data);
}

class ZakatRemoteDatasourceImpl implements ZakatRemoteDatasource {
  final DioClient _dioClient;

  ZakatRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<ZakatCalculation> calculate(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.zakatCalculate(storeId),
      );
      return _mapCalculation(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ZakatSettings?> getSettings(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.zakatSettings(storeId),
      );
      if (response.data == null) return null;
      return _mapSettings(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ZakatSettings> upsertSettings(String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.zakatSettings(storeId),
        data: data,
      );
      return _mapSettings(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<ZakatPayment>> getPayments(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.zakatPayments(storeId),
      );
      final list = response.data as List;
      return list
          .map((json) => _mapPayment(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ZakatPayment> createPayment(String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.zakatPayments(storeId),
        data: data,
      );
      return _mapPayment(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ZakatCalculation _mapCalculation(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    return ZakatCalculation(
      stockValue: (breakdown['inventoryValue'] as num?)?.toDouble() ?? 0,
      receivables: (breakdown['receivables'] as num?)?.toDouble() ?? 0,
      payables: (breakdown['payables'] as num?)?.toDouble() ?? 0,
      netAssets: (json['netAssets'] as num?)?.toDouble() ?? 0,
      nisabAmount: (json['nisabAmount'] as num?)?.toDouble() ?? 0,
      zakatDue: (json['zakatDue'] as num?)?.toDouble() ?? 0,
      isAboveNisab: json['isAboveNisab'] as bool? ?? false,
    );
  }

  ZakatSettings _mapSettings(Map<String, dynamic> json) {
    return ZakatSettings(
      id: (json['id'] as String?) ?? '',
      storeId: (json['storeId'] as String?) ?? '',
      nisabGold: (json['nisabGold'] as num?)?.toDouble() ?? 85,
      nisabSilver: (json['nisabSilver'] as num?)?.toDouble() ?? 595,
      nisabCurrency: json['nisabCurrency'] as String? ?? 'TJS',
      nisabAmount: (json['nisabAmount'] as num?)?.toDouble() ?? 0,
      haulStartDate: json['haulStartDate'] != null
          ? DateTime.parse(json['haulStartDate'] as String)
          : null,
      zakatRate: (json['zakatRate'] as num?)?.toDouble() ?? 2.5,
      includeStock: json['includeStock'] as bool? ?? true,
      includeCash: json['includeCash'] as bool? ?? true,
      includeDebts: json['includeDebts'] as bool? ?? true,
    );
  }

  ZakatPayment _mapPayment(Map<String, dynamic> json) {
    return ZakatPayment(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      amount: (json['amount'] as num).toDouble(),
      totalAssets: (json['totalAssets'] as num).toDouble(),
      zakatDue: (json['zakatDue'] as num).toDouble(),
      breakdown: json['breakdown'] as Map<String, dynamic>? ?? {},
      notes: json['notes'] as String?,
      paidAt: DateTime.parse(json['paidAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
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
