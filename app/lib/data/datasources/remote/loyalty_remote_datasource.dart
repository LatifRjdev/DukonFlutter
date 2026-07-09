import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_list_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/loyalty_analytics.dart';
import '../../../domain/entities/loyalty_transaction.dart';

abstract class LoyaltyRemoteDatasource {
  Future<Map<String, dynamic>> getSettings(String storeId);
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data);
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId);
  Future<LoyaltyAnalytics> getAnalytics(
      String storeId, DateTime from, DateTime to);
}

class LoyaltyRemoteDatasourceImpl implements LoyaltyRemoteDatasource {
  final DioClient _dioClient;

  LoyaltyRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.loyaltySettings(storeId),
      );
      final json = decodeApiObject(response.data);
      return json ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.loyaltySettings(storeId),
        data: data,
      );
      final json = decodeApiObject(response.data);
      return json ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.loyaltyCustomerBalance(storeId, customerId),
      );
      final json = decodeApiObject(response.data) ?? <String, dynamic>{};
      final points = (json['points'] as num?)?.toInt() ?? 0;
      final rawList = json['transactions'];
      final transactions = (rawList is List)
          ? rawList
              .whereType<Map<String, dynamic>>()
              .map(LoyaltyTransaction.fromJson)
              .toList()
          : <LoyaltyTransaction>[];
      return (points: points, transactions: transactions);
    } on DioException {
      // Intentional fallback: any HTTP error (e.g. 403 = plan not eligible,
      // 404 = customer has no loyalty record) silently returns zero balance
      // rather than surfacing an error in the POS UI.
      return (points: 0, transactions: <LoyaltyTransaction>[]);
    }
  }

  @override
  Future<LoyaltyAnalytics> getAnalytics(
      String storeId, DateTime from, DateTime to) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.loyaltyAnalytics(storeId),
        queryParameters: {
          'from': from.toIso8601String().substring(0, 10),
          'to': to.toIso8601String().substring(0, 10),
        },
      );
      final json = decodeApiObject(response.data) ?? <String, dynamic>{};
      return LoyaltyAnalytics.fromJson(json);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = e.response?.statusCode;
    final rawMessage =
        (e.response?.data is Map) ? e.response?.data['message'] : null;
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
