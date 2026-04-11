import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/staff_repository.dart';
import 'staff_form_event.dart';
import 'staff_form_state.dart';

class StaffFormBloc extends Bloc<StaffFormEvent, StaffFormState> {
  final StaffRepository _staffRepository;

  StaffFormBloc({required StaffRepository staffRepository})
      : _staffRepository = staffRepository,
        super(const StaffFormInitial()) {
    on<InitStaffForm>(_onInitStaffForm);
    on<UpdateField>(_onUpdateField);
    on<SubmitStaffForm>(_onSubmitStaffForm);
  }

  void _onInitStaffForm(InitStaffForm event, Emitter<StaffFormState> emit) {
    final member = event.staffMember;
    if (member != null) {
      emit(StaffFormState(
        name: member.name,
        phone: member.phone ?? '',
        role: member.role,
        salary: member.salary ?? 0,
        commission: member.commission ?? 0,
        isEditing: true,
        editingId: member.id,
      ));
    } else {
      emit(const StaffFormInitial());
    }
  }

  void _onUpdateField(UpdateField event, Emitter<StaffFormState> emit) {
    switch (event.field) {
      case 'name':
        emit(state.copyWith(name: event.value as String));
        break;
      case 'phone':
        emit(state.copyWith(phone: event.value as String));
        break;
      case 'role':
        emit(state.copyWith(role: event.value as String));
        break;
      case 'salary':
        emit(state.copyWith(salary: (event.value as num).toDouble()));
        break;
      case 'commission':
        emit(state.copyWith(commission: (event.value as num).toDouble()));
        break;
    }
  }

  Future<void> _onSubmitStaffForm(SubmitStaffForm event, Emitter<StaffFormState> emit) async {
    emit(StaffFormLoading(
      name: state.name,
      phone: state.phone,
      role: state.role,
      salary: state.salary,
      commission: state.commission,
      isEditing: state.isEditing,
      editingId: state.editingId,
    ));
    try {
      final staffMember = state.isEditing && state.editingId != null
          ? await _staffRepository.updateStaff(event.storeId, state.editingId!, event.data)
          : await _staffRepository.createStaff(event.storeId, event.data);
      emit(StaffFormSuccess(
        staffMember: staffMember,
        name: state.name,
        phone: state.phone,
        role: state.role,
        salary: state.salary,
        commission: state.commission,
        isEditing: state.isEditing,
        editingId: state.editingId,
      ));
    } catch (e) {
      emit(StaffFormError(
        message: mapErrorToUserMessage(e),
        name: state.name,
        phone: state.phone,
        role: state.role,
        salary: state.salary,
        commission: state.commission,
        isEditing: state.isEditing,
        editingId: state.editingId,
      ));
    }
  }
}
