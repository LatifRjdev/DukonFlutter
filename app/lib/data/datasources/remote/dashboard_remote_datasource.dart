import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/sale.dart';
import '../../../presentation/blocs/dashboard/dashboard_state.dart';

abstract class DashboardRemoteDatasource {
  Future<DashboardStats> getOverview(String storeId, {String period = 'today'});
}

class DashboardRemoteDatasourceImpl implements DashboardRemoteDatasource {
  final DioClient _dioClient;

  DashboardRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<DashboardStats> getOverview(String storeId, {String period = 'today'}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.financeOverview(storeId),
        queryParameters: {'period': period},
      );
      final json = response.data as Map<String, dynamic>;

      final salesList = json['recentSales'] as List? ?? [];
      final recentSales = salesList.map((s) {
        final m = s as Map<String, dynamic>;
        return Sale(
          id: m['id'] as String? ?? '',
          storeId: storeId,
          receiptNo: m['receiptNo'] as String? ?? '',
          subtotal: (m['total'] as num?)?.toDouble() ?? 0,
          total: (m['total'] as num?)?.toDouble() ?? 0,
          paymentType: m['paymentType'] as String? ?? 'CASH',
          paidAmount: (m['total'] as num?)?.toDouble() ?? 0,
          status: m['status'] as String? ?? 'COMPLETED',
          customerName: m['customerName'] as String?,
          createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();

      return DashboardStats(
        todayRevenue: (json['todayRevenue'] as num?)?.toDouble() ?? (json['revenue'] as num?)?.toDouble() ?? 0,
        todayCost: (json['todayCost'] as num?)?.toDouble() ?? (json['costOfGoods'] as num?)?.toDouble() ?? 0,
        todayExpenses: (json['todayExpenses'] as num?)?.toDouble() ?? (json['expenses'] as num?)?.toDouble() ?? 0,
        todayProfit: (json['todayProfit'] as num?)?.toDouble() ?? (json['netProfit'] as num?)?.toDouble() ?? 0,
        todaySalesCount: (json['todaySalesCount'] as num?)?.toInt() ?? (json['salesCount'] as num?)?.toInt() ?? 0,
        totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
        lowStockProducts: (json['lowStockProducts'] as num?)?.toInt() ?? 0,
        customerDebtsTotal: (json['customerDebtsTotal'] as num?)?.toDouble() ?? 0,
        supplierDebtsTotal: (json['supplierDebtsTotal'] as num?)?.toDouble() ?? 0,
        recentSales: recentSales,
      );
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
