import 'package:equatable/equatable.dart';
import '../../../domain/entities/staff_member.dart';

abstract class StaffState extends Equatable {
  const StaffState();
  @override
  List<Object?> get props => [];
}

class StaffInitial extends StaffState {}
class StaffLoading extends StaffState {}

class StaffLoaded extends StaffState {
  final List<StaffMember> staff;
  final int total;
  final int totalPages;
  const StaffLoaded({required this.staff, required this.total, required this.totalPages});
  @override
  List<Object?> get props => [staff, total, totalPages];
}

class StaffDetailLoaded extends StaffState {
  final StaffMember staffMember;
  const StaffDetailLoaded(this.staffMember);
  @override
  List<Object?> get props => [staffMember];
}

class StaffError extends StaffState {
  final String message;
  const StaffError(this.message);
  @override
  List<Object?> get props => [message];
}
