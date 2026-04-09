import 'package:equatable/equatable.dart';
import '../../../domain/entities/payroll_period.dart';

abstract class PayrollState extends Equatable {
  const PayrollState();
  @override
  List<Object?> get props => [];
}

class PayrollInitial extends PayrollState {}
class PayrollLoading extends PayrollState {}

class PayrollPeriodsLoaded extends PayrollState {
  final List<PayrollPeriod> periods;
  const PayrollPeriodsLoaded({required this.periods});
  @override
  List<Object?> get props => [periods];
}

class PayrollPeriodDetailLoaded extends PayrollState {
  final PayrollPeriod period;
  const PayrollPeriodDetailLoaded({required this.period});
  @override
  List<Object?> get props => [period];
}

class PayrollError extends PayrollState {
  final String message;
  const PayrollError(this.message);
  @override
  List<Object?> get props => [message];
}
