import 'package:equatable/equatable.dart';

abstract class RolesEvent extends Equatable {
  const RolesEvent();
  @override
  List<Object?> get props => [];
}

class LoadRoles extends RolesEvent {
  final String storeId;
  const LoadRoles({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class UpdatePermission extends RolesEvent {
  final String storeId;
  final String role;
  final String permission;
  final bool value;
  const UpdatePermission({required this.storeId, required this.role, required this.permission, required this.value});
  @override
  List<Object?> get props => [storeId, role, permission, value];
}

class SavePermissions extends RolesEvent {
  final String storeId;
  final String role;
  final Map<String, bool> permissions;
  const SavePermissions({required this.storeId, required this.role, required this.permissions});
  @override
  List<Object?> get props => [storeId, role, permissions];
}
