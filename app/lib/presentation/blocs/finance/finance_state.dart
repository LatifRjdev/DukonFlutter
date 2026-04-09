import 'package:equatable/equatable.dart';
import '../../../domain/entities/finance_summary.dart';

abstract class FinanceState extends Equatable {
  const FinanceState();
  @override
  List<Object?> get props => [];
}

class FinanceInitial extends FinanceState {}
class FinanceLoading extends FinanceState {}

class FinanceLoaded extends FinanceState {
  final FinanceSummary summary;
  final String period;
  const FinanceLoaded({required this.summary, this.period = 'month'});
  @override
  List<Object?> get props => [summary, period];
}

class FinanceError extends FinanceState {
  final String message;
  const FinanceError(this.message);
  @override
  List<Object?> get props => [message];
}
