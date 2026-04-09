import 'package:equatable/equatable.dart';
import '../../../domain/entities/staff_member.dart';

abstract class StaffFormEvent extends Equatable {
  const StaffFormEvent();
  @override
  List<Object?> get props => [];
}

class InitStaffForm extends StaffFormEvent {
  final StaffMember? staffMember;
  const InitStaffForm({this.staffMember});
  @override
  List<Object?> get props => [staffMember];
}

class SubmitStaffForm extends StaffFormEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const SubmitStaffForm({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class UpdateField extends StaffFormEvent {
  final String field;
  final dynamic value;
  const UpdateField({required this.field, required this.value});
  @override
  List<Object?> get props => [field, value];
}
