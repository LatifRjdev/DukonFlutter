import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/entities/role_permission.dart';
import '../../../domain/repositories/staff_repository.dart';
import 'roles_event.dart';
import 'roles_state.dart';

class RolesBloc extends Bloc<RolesEvent, RolesState> {
  final StaffRepository _staffRepository;

  RolesBloc({required StaffRepository staffRepository})
      : _staffRepository = staffRepository,
        super(RolesInitial()) {
    on<LoadRoles>(_onLoadRoles);
    on<UpdatePermission>(_onUpdatePermission);
    on<SavePermissions>(_onSavePermissions);
  }

  Future<void> _onLoadRoles(LoadRoles event, Emitter<RolesState> emit) async {
    emit(RolesLoading());
    try {
      final roles = await _staffRepository.getRoles(event.storeId);
      emit(RolesLoaded(roles: roles));
    } catch (e) {
      emit(RolesError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onUpdatePermission(UpdatePermission event, Emitter<RolesState> emit) async {
    final currentState = state;
    if (currentState is RolesLoaded) {
      final updatedRoles = currentState.roles.map((rolePermission) {
        if (rolePermission.role == event.role) {
          final updatedPermissions = Map<String, bool>.from(rolePermission.permissions);
          updatedPermissions[event.permission] = event.value;
          return RolePermission(role: rolePermission.role, permissions: updatedPermissions);
        }
        return rolePermission;
      }).toList();
      emit(RolesLoaded(roles: updatedRoles));
    }
  }

  Future<void> _onSavePermissions(SavePermissions event, Emitter<RolesState> emit) async {
    emit(RolesLoading());
    try {
      await _staffRepository.updateRolePermissions(event.storeId, event.role, event.permissions);
      add(LoadRoles(storeId: event.storeId));
    } catch (e) {
      emit(RolesError(mapErrorToUserMessage(e)));
    }
  }
}
