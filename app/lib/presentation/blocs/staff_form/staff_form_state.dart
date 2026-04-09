import 'package:equatable/equatable.dart';
import '../../../domain/entities/staff_member.dart';

class StaffFormState extends Equatable {
  final String name;
  final String phone;
  final String role;
  final double salary;
  final double commission;
  final bool isEditing;
  final String? editingId;
  final bool isLoading;
  final bool isSuccess;
  final StaffMember? savedStaffMember;
  final String? errorMessage;

  const StaffFormState({
    this.name = '',
    this.phone = '',
    this.role = 'seller',
    this.salary = 0,
    this.commission = 0,
    this.isEditing = false,
    this.editingId,
    this.isLoading = false,
    this.isSuccess = false,
    this.savedStaffMember,
    this.errorMessage,
  });

  StaffFormState copyWith({
    String? name,
    String? phone,
    String? role,
    double? salary,
    double? commission,
    bool? isEditing,
    String? editingId,
    bool? isLoading,
    bool? isSuccess,
    StaffMember? savedStaffMember,
    String? errorMessage,
  }) {
    return StaffFormState(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      salary: salary ?? this.salary,
      commission: commission ?? this.commission,
      isEditing: isEditing ?? this.isEditing,
      editingId: editingId ?? this.editingId,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      savedStaffMember: savedStaffMember ?? this.savedStaffMember,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [name, phone, role, salary, commission, isEditing, editingId, isLoading, isSuccess, savedStaffMember, errorMessage];
}

class StaffFormInitial extends StaffFormState {
  const StaffFormInitial() : super();
}

class StaffFormLoading extends StaffFormState {
  const StaffFormLoading({
    required super.name,
    required super.phone,
    required super.role,
    required super.salary,
    required super.commission,
    required super.isEditing,
    super.editingId,
  }) : super(isLoading: true);
}

class StaffFormSuccess extends StaffFormState {
  const StaffFormSuccess({
    required StaffMember staffMember,
    required super.name,
    required super.phone,
    required super.role,
    required super.salary,
    required super.commission,
    required super.isEditing,
    super.editingId,
  }) : super(isSuccess: true, savedStaffMember: staffMember);
}

class StaffFormError extends StaffFormState {
  const StaffFormError({
    required String message,
    required super.name,
    required super.phone,
    required super.role,
    required super.salary,
    required super.commission,
    required super.isEditing,
    super.editingId,
  }) : super(errorMessage: message);
}
