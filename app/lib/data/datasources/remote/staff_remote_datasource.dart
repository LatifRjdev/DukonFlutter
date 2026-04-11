import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_list_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/staff_member.dart';
import '../../../domain/entities/role_permission.dart';

abstract class StaffRemoteDatasource {
  Future<({List<StaffMember> data, int total, int totalPages})> getStaff(
    String storeId, {
    int page = 1,
    String? search,
    String? role,
  });
  Future<StaffMember> getStaffMember(String storeId, String id);
  Future<StaffMember> createStaff(String storeId, Map<String, dynamic> data);
  Future<StaffMember> updateStaff(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteStaff(String storeId, String id);
  Future<List<RolePermission>> getRoles(String storeId);
  Future<RolePermission> getRolePermissions(String storeId, String role);
  Future<RolePermission> updateRolePermissions(String storeId, String role, Map<String, bool> permissions);
}

class StaffRemoteDatasourceImpl implements StaffRemoteDatasource {
  final DioClient _dioClient;

  StaffRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<StaffMember> data, int total, int totalPages})> getStaff(
    String storeId, {
    int page = 1,
    String? search,
    String? role,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.staff(storeId),
        queryParameters: {
          'page': page,
          if (search != null) 'search': search,
          if (role != null) 'role': role,
        },
      );

      final decoded = ApiListResponse.decode<StaffMember>(
        response.data,
        StaffMember.fromJson,
      );
      return (
        data: decoded.items,
        total: decoded.total,
        totalPages: decoded.totalPages,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<StaffMember> getStaffMember(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.staffMember(storeId, id),
      );
      return StaffMember.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<StaffMember> createStaff(String storeId, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.staff(storeId),
        data: data,
      );
      return StaffMember.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<StaffMember> updateStaff(String storeId, String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.staffMember(storeId, id),
        data: data,
      );
      return StaffMember.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteStaff(String storeId, String id) async {
    try {
      await _dioClient.delete(
        ApiEndpoints.staffMember(storeId, id),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<RolePermission>> getRoles(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.roles(storeId),
      );
      final list = response.data as List;
      return list
          .map((json) => RolePermission.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<RolePermission> getRolePermissions(String storeId, String role) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.rolePermissions(storeId, role),
      );
      return RolePermission.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<RolePermission> updateRolePermissions(
      String storeId, String role, Map<String, bool> permissions) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.rolePermissions(storeId, role),
        data: {'permissions': permissions},
      );
      return RolePermission.fromJson(response.data as Map<String, dynamic>);
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
