import '../entities/staff_member.dart';
import '../entities/role_permission.dart';

abstract class StaffRepository {
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
