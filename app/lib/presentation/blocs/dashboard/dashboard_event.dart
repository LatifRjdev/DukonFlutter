import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class DashboardLoadRequested extends DashboardEvent {
  final String storeId;
  final String period;
  const DashboardLoadRequested(this.storeId, {this.period = 'today'});
  @override
  List<Object?> get props => [storeId, period];
}

class DashboardRefreshRequested extends DashboardEvent {
  final String storeId;
  final String period;
  const DashboardRefreshRequested(this.storeId, {this.period = 'today'});
  @override
  List<Object?> get props => [storeId, period];
}

class DashboardPeriodChanged extends DashboardEvent {
  final String storeId;
  final String period;
  const DashboardPeriodChanged(this.storeId, this.period);
  @override
  List<Object?> get props => [storeId, period];
}
