import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/payroll_period.dart';

abstract class PayrollRemoteDatasource {
  Future<PayrollPeriod> calculatePayroll(String storeId, int month, int year);
  Future<List<PayrollPeriod>> getPayrollPeriods(String storeId);
  Future<PayrollPeriod> getPayrollPeriod(String storeId, String periodId);
  Future<void> addAdjustment(String storeId, String periodId, Map<String, dynamic> data);
  Future<void> removeAdjustment(String storeId, String periodId, String adjustmentId);
  Future<void> payIndividual(String storeId, String periodId, String payrollId);
  Future<void> payAll(String storeId, String periodId);
}

class PayrollRemoteDatasourceImpl implements PayrollRemoteDatasource {
  final DioClient _dioClient;

  PayrollRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<PayrollPeriod> calculatePayroll(String storeId, int month, int year) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.payrollCalculate(storeId),
        data: {'month': month, 'year': year},
      );
      return PayrollPeriod.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<PayrollPeriod>> getPayrollPeriods(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.payrollPeriods(storeId),
      );
      final list = response.data as List;
      return list
          .map((json) => PayrollPeriod.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<PayrollPeriod> getPayrollPeriod(String storeId, String periodId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.payrollPeriod(storeId, periodId),
      );
      return PayrollPeriod.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> addAdjustment(
      String storeId, String periodId, Map<String, dynamic> data) async {
    try {
      await _dioClient.post(
        ApiEndpoints.payrollAdjustments(storeId, periodId),
        data: data,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> removeAdjustment(
      String storeId, String periodId, String adjustmentId) async {
    try {
      await _dioClient.delete(
        ApiEndpoints.payrollAdjustment(storeId, periodId, adjustmentId),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> payIndividual(
      String storeId, String periodId, String payrollId) async {
    try {
      await _dioClient.post(
        ApiEndpoints.payrollPay(storeId, periodId, payrollId),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> payAll(String storeId, String periodId) async {
    try {
      await _dioClient.post(
        ApiEndpoints.payrollPayAll(storeId, periodId),
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
