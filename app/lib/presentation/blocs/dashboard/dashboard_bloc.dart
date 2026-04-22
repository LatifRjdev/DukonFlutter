import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/dashboard_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRepository _dashboardRepository;

  DashboardBloc({required DashboardRepository dashboardRepository})
      : _dashboardRepository = dashboardRepository,
        super(DashboardInitial()) {
    on<DashboardLoadRequested>(_onLoadRequested);
    on<DashboardRefreshRequested>(_onRefreshRequested);
    on<DashboardPeriodChanged>(_onPeriodChanged);
  }

  Future<void> _onLoadRequested(DashboardLoadRequested event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final stats = await _dashboardRepository.getOverview(event.storeId, period: event.period);
      emit(DashboardLoaded(stats, period: event.period));
    } catch (e) {
      emit(DashboardError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onRefreshRequested(DashboardRefreshRequested event, Emitter<DashboardState> emit) async {
    try {
      final stats = await _dashboardRepository.getOverview(event.storeId, period: event.period);
      emit(DashboardLoaded(stats, period: event.period));
    } catch (e) {
      if (state is DashboardLoaded) return;
      emit(DashboardError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPeriodChanged(DashboardPeriodChanged event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final stats = await _dashboardRepository.getOverview(event.storeId, period: event.period, startDate: event.startDate, endDate: event.endDate);
      emit(DashboardLoaded(stats, period: event.period));
    } catch (e) {
      emit(DashboardError(mapErrorToUserMessage(e)));
    }
  }
}
