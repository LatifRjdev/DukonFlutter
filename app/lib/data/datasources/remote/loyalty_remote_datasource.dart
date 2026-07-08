import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_list_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/loyalty_transaction.dart';

abstract class LoyaltyRemoteDatasource {
  Future<Map<String, dynamic>> getSettings(String storeId);
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data);
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId);
}

class LoyaltyRemoteDatasourceImpl implements LoyaltyRemoteDatasource {
  final DioClient _dioClient;

  LoyaltyRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) async {
    final response = await _dioClient.get(
      ApiEndpoints.loyaltySettings(storeId),
    );
    final json = decodeApiObject(response.data);
    return json ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data) async {
    final response = await _dioClient.put(
      ApiEndpoints.loyaltySettings(storeId),
      data: data,
    );
    final json = decodeApiObject(response.data);
    return json ?? <String, dynamic>{};
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
      // 403 = plan not eligible; any HTTP error falls back to empty balance
      return (points: 0, transactions: <LoyaltyTransaction>[]);
    }
  }
}
