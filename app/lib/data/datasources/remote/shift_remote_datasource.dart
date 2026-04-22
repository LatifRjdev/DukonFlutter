import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/entities/z_report.dart';

abstract class ShiftRemoteDatasource {
  Future<ShiftModel> openShift(String storeId, Map<String, dynamic> data);
  Future<ShiftModel> closeShift(String storeId, String shiftId, Map<String, dynamic> data);
  Future<ShiftModel?> getCurrentShift(String storeId);
  Future<({List<ShiftModel> data, int total, int totalPages})> getShifts(
    String storeId, {
    int page = 1,
    String? staffId,
    String? dateFrom,
    String? dateTo,
  });
  Future<ShiftModel> getShift(String storeId, String id);
  Future<ZReport> getZReport(String storeId, String shiftId);
}

class ShiftRemoteDatasourceImpl implements ShiftRemoteDatasource {
  final DioClient _dioClient;

  ShiftRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<ShiftModel> openShift(String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.shiftOpen(storeId),
        data: data,
      );
      return ShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ShiftModel> closeShift(
      String storeId, String shiftId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.shiftClose(storeId, shiftId),
        data: data,
      );
      return ShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ShiftModel?> getCurrentShift(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.shiftCurrent(storeId),
      );
      if (response.data == null) return null;
      return ShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _handleDioError(e);
    }
  }

  @override
  Future<({List<ShiftModel> data, int total, int totalPages})> getShifts(
    String storeId, {
    int page = 1,
    String? staffId,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.shifts(storeId),
        queryParameters: {
          'page': page,
          'staffId': ?staffId,
          'dateFrom': ?dateFrom,
          'dateTo': ?dateTo,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      final list = responseData['data'] as List;

      return (
        data: list
            .map((json) => ShiftModel.fromJson(json as Map<String, dynamic>))
            .toList(),
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ShiftModel> getShift(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.shiftDetail(storeId, id),
      );
      return ShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ZReport> getZReport(String storeId, String shiftId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.shiftZReport(storeId, shiftId),
      );
      return ZReport.fromJson(response.data as Map<String, dynamic>);
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
