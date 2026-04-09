import 'package:equatable/equatable.dart';
import '../../../domain/entities/role_permission.dart';

abstract class RolesState extends Equatable {
  const RolesState();
  @override
  List<Object?> get props => [];
}

class RolesInitial extends RolesState {}
class RolesLoading extends RolesState {}

class RolesLoaded extends RolesState {
  final List<RolePermission> roles;
  const RolesLoaded({required this.roles});
  @override
  List<Object?> get props => [roles];
}

class RolesError extends RolesState {
  final String message;
  const RolesError(this.message);
  @override
  List<Object?> get props => [message];
}
