import 'package:equatable/equatable.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/entities/z_report.dart';

abstract class ShiftState extends Equatable {
  const ShiftState();
  @override
  List<Object?> get props => [];
}

class ShiftInitial extends ShiftState {}
class ShiftLoading extends ShiftState {}

class ShiftLoaded extends ShiftState {
  final ShiftModel? currentShift;
  final List<ShiftModel> shifts;
  final int total;
  final int totalPages;
  const ShiftLoaded({this.currentShift, this.shifts = const [], this.total = 0, this.totalPages = 0});
  @override
  List<Object?> get props => [currentShift, shifts, total, totalPages];
}

class ZReportLoaded extends ShiftState {
  final ZReport report;
  const ZReportLoaded({required this.report});
  @override
  List<Object?> get props => [report];
}

class ShiftOpened extends ShiftState {
  final ShiftModel shift;
  const ShiftOpened(this.shift);
  @override
  List<Object?> get props => [shift];
}

class ShiftClosed extends ShiftState {
  final ShiftModel shift;
  const ShiftClosed(this.shift);
  @override
  List<Object?> get props => [shift];
}

class ShiftError extends ShiftState {
  final String message;
  const ShiftError(this.message);
  @override
  List<Object?> get props => [message];
}
