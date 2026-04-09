import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/finance_repository.dart';
import 'finance_event.dart';
import 'finance_state.dart';

class FinanceBloc extends Bloc<FinanceEvent, FinanceState> {
  final FinanceRepository _financeRepository;

  FinanceBloc({required FinanceRepository financeRepository})
      : _financeRepository = financeRepository,
        super(FinanceInitial()) {
    on<FinanceDashboardRequested>(_onDashboardRequested);
    on<FinancePeriodChanged>(_onPeriodChanged);
  }

  Future<void> _onDashboardRequested(FinanceDashboardRequested event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      final summary = await _financeRepository.getDashboard(
        event.storeId,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(FinanceLoaded(summary: summary));
    } catch (e) {
      emit(FinanceError(e.toString()));
    }
  }

  Future<void> _onPeriodChanged(FinancePeriodChanged event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      final summary = await _financeRepository.getSummary(event.storeId, period: event.period);
      emit(FinanceLoaded(summary: summary, period: event.period));
    } catch (e) {
      emit(FinanceError(e.toString()));
    }
  }
}
