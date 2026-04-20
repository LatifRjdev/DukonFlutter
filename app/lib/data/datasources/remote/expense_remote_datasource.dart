import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/expense.dart';

abstract class ExpenseRemoteDatasource {
  Future<({List<Expense> data, int total, int totalPages})> getExpenses(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  });

  Future<Expense> getExpense(String storeId, String id);
  Future<Expense> createExpense(String storeId, Map<String, dynamic> data);
  Future<Expense> updateExpense(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteExpense(String storeId, String id);
}

class ExpenseRemoteDatasourceImpl implements ExpenseRemoteDatasource {
  final DioClient _dioClient;

  ExpenseRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<Expense> data, int total, int totalPages})> getExpenses(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.expenses(storeId),
        queryParameters: {
          'page': page,
          'limit': limit,
          'category': ?category,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
          'search': ?search,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      final list = responseData['data'] as List;

      return (
        data: list
            .map((json) => _mapExpense(json as Map<String, dynamic>))
            .toList(),
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Expense> getExpense(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.expense(storeId, id),
      );
      return _mapExpense(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Expense> createExpense(String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.expenses(storeId),
        data: data,
      );
      return _mapExpense(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Expense> updateExpense(String storeId, String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.expense(storeId, id),
        data: data,
      );
      return _mapExpense(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteExpense(String storeId, String id) async {
    try {
      await _dioClient.delete(
        ApiEndpoints.expense(storeId, id),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Expense _mapExpense(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringDay: json['recurringDay'] as int?,
      createdBy: json['createdBy'] as String?,
      date: DateTime.parse(json['date'] as String),
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
