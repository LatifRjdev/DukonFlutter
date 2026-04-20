import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/investment.dart';

abstract class InvestmentRemoteDatasource {
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Investment> getInvestment(String storeId, String id);
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data);
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteInvestment(String storeId, String id);
  Future<InvestmentSummary> getSummary(String storeId);
}

class InvestmentRemoteDatasourceImpl implements InvestmentRemoteDatasource {
  final DioClient _dioClient;

  InvestmentRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.investments(storeId),
        queryParameters: {
          'page': page,
          'limit': limit,
          'status': ?status,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      final list = responseData['data'] as List;

      return (
        data: list
            .map((json) => _mapInvestment(json as Map<String, dynamic>))
            .toList(),
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Investment> getInvestment(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.investment(storeId, id),
      );
      return _mapInvestment(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.investments(storeId),
        data: data,
      );
      return _mapInvestment(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.investment(storeId, id),
        data: data,
      );
      return _mapInvestment(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteInvestment(String storeId, String id) async {
    try {
      await _dioClient.delete(
        ApiEndpoints.investment(storeId, id),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<InvestmentSummary> getSummary(String storeId) async {
    try {
      final response = await _dioClient.get(
        '${ApiEndpoints.investments(storeId)}/summary',
      );
      final json = response.data as Map<String, dynamic>;
      return InvestmentSummary(
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        totalCount: json['totalCount'] as int? ?? 0,
        activeAmount: (json['activeAmount'] as num?)?.toDouble() ?? 0,
        activeCount: json['activeCount'] as int? ?? 0,
        completedAmount: (json['completedAmount'] as num?)?.toDouble() ?? 0,
        completedReturnAmount: (json['completedReturnAmount'] as num?)?.toDouble() ?? 0,
        completedCount: json['completedCount'] as int? ?? 0,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Investment _mapInvestment(Map<String, dynamic> json) {
    return Investment(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      returnAmount: (json['returnAmount'] as num?)?.toDouble(),
      investorName: json['investorName'] as String,
      investorPhone: json['investorPhone'] as String?,
      status: json['status'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
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
