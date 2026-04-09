import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/finance_summary.dart';

abstract class FinanceRemoteDatasource {
  Future<FinanceSummary> getDashboard(String storeId, {DateTime? startDate, DateTime? endDate});
  Future<FinanceSummary> getSummary(String storeId, {required String period, DateTime? startDate, DateTime? endDate});
}

class FinanceRemoteDatasourceImpl implements FinanceRemoteDatasource {
  final DioClient _dioClient;

  FinanceRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<FinanceSummary> getDashboard(String storeId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.financeDashboard(storeId),
        queryParameters: {
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );
      return _mapSummary(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<FinanceSummary> getSummary(String storeId, {required String period, DateTime? startDate, DateTime? endDate}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.financeSummary(storeId),
        queryParameters: {
          'period': period,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );
      final json = response.data as Map<String, dynamic>;
      // Summary endpoint returns chart data with salesByDay and expensesByDay
      final salesByDay = json['salesByDay'] as List? ?? [];
      final expensesByDay = json['expensesByDay'] as List? ?? [];

      double totalIncome = 0;
      int salesCount = 0;
      for (final day in salesByDay) {
        totalIncome += (day['revenue'] as num?)?.toDouble() ?? 0;
        salesCount += (day['count'] as num?)?.toInt() ?? 0;
      }

      double totalExpenses = 0;
      for (final day in expensesByDay) {
        totalExpenses += (day['total'] as num?)?.toDouble() ?? 0;
      }

      return FinanceSummary(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        profit: totalIncome - totalExpenses,
        salesCount: salesCount,
        avgCheck: salesCount > 0 ? totalIncome / salesCount : 0,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  FinanceSummary _mapSummary(Map<String, dynamic> json) {
    final topProductsList = json['topProducts'] as List? ?? [];
    return FinanceSummary(
      totalIncome: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
      avgCheck: (json['averageCheck'] as num?)?.toDouble() ?? 0,
      topProducts: topProductsList.map((p) {
        final m = p as Map<String, dynamic>;
        return TopProduct(
          id: m['productId'] as String? ?? '',
          name: m['productName'] as String? ?? '',
          quantity: (m['totalQuantity'] as num?)?.toInt() ?? 0,
          revenue: (m['totalRevenue'] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
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
