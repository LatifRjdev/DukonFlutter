import 'package:equatable/equatable.dart';

abstract class FinanceEvent extends Equatable {
  const FinanceEvent();
  @override
  List<Object?> get props => [];
}

class FinanceDashboardRequested extends FinanceEvent {
  final String storeId;
  final DateTime? startDate;
  final DateTime? endDate;
  const FinanceDashboardRequested({required this.storeId, this.startDate, this.endDate});
  @override
  List<Object?> get props => [storeId, startDate, endDate];
}

class FinancePeriodChanged extends FinanceEvent {
  final String storeId;
  final String period;
  const FinancePeriodChanged({required this.storeId, required this.period});
  @override
  List<Object?> get props => [storeId, period];
}
