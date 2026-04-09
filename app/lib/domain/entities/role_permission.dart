import 'package:equatable/equatable.dart';

class RolePermission extends Equatable {
  final String role;
  final Map<String, bool> permissions;

  const RolePermission({
    required this.role,
    required this.permissions,
  });

  factory RolePermission.fromJson(Map<String, dynamic> json) {
    return RolePermission(
      role: json['role'] as String,
      permissions: (json['permissions'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as bool)),
    );
  }

  @override
  List<Object?> get props => [role, permissions];
}
