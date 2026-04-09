import '../../domain/entities/staff_member.dart';
import '../../domain/entities/role_permission.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/remote/staff_remote_datasource.dart';

class StaffRepositoryImpl implements StaffRepository {
  final StaffRemoteDatasource _remoteDatasource;

  StaffRepositoryImpl({required StaffRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<({List<StaffMember> data, int total, int totalPages})> getStaff(
    String storeId, {
    int page = 1,
    String? search,
    String? role,
  }) {
    return _remoteDatasource.getStaff(
      storeId,
      page: page,
      search: search,
      role: role,
    );
  }

  @override
  Future<StaffMember> getStaffMember(String storeId, String id) {
    return _remoteDatasource.getStaffMember(storeId, id);
  }

  @override
  Future<StaffMember> createStaff(String storeId, Map<String, dynamic> data) {
    return _remoteDatasource.createStaff(storeId, data);
  }

  @override
  Future<StaffMember> updateStaff(String storeId, String id, Map<String, dynamic> data) {
    return _remoteDatasource.updateStaff(storeId, id, data);
  }

  @override
  Future<void> deleteStaff(String storeId, String id) {
    return _remoteDatasource.deleteStaff(storeId, id);
  }

  @override
  Future<List<RolePermission>> getRoles(String storeId) {
    return _remoteDatasource.getRoles(storeId);
  }

  @override
  Future<RolePermission> getRolePermissions(String storeId, String role) {
    return _remoteDatasource.getRolePermissions(storeId, role);
  }

  @override
  Future<RolePermission> updateRolePermissions(String storeId, String role, Map<String, bool> permissions) {
    return _remoteDatasource.updateRolePermissions(storeId, role, permissions);
  }
}
