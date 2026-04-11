import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/payroll_repository.dart';
import 'payroll_event.dart';
import 'payroll_state.dart';

class PayrollBloc extends Bloc<PayrollEvent, PayrollState> {
  final PayrollRepository _payrollRepository;

  PayrollBloc({required PayrollRepository payrollRepository})
      : _payrollRepository = payrollRepository,
        super(PayrollInitial()) {
    on<LoadPayrollPeriods>(_onLoadPayrollPeriods);
    on<LoadPayrollPeriod>(_onLoadPayrollPeriod);
    on<CalculatePayroll>(_onCalculatePayroll);
    on<AddAdjustment>(_onAddAdjustment);
    on<RemoveAdjustment>(_onRemoveAdjustment);
    on<PayIndividual>(_onPayIndividual);
    on<PayAll>(_onPayAll);
  }

  Future<void> _onLoadPayrollPeriods(LoadPayrollPeriods event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      final periods = await _payrollRepository.getPayrollPeriods(event.storeId);
      emit(PayrollPeriodsLoaded(periods: periods));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onLoadPayrollPeriod(LoadPayrollPeriod event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      final period = await _payrollRepository.getPayrollPeriod(event.storeId, event.periodId);
      emit(PayrollPeriodDetailLoaded(period: period));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onCalculatePayroll(CalculatePayroll event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      await _payrollRepository.calculatePayroll(event.storeId, event.month, event.year);
      add(LoadPayrollPeriods(storeId: event.storeId));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onAddAdjustment(AddAdjustment event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      await _payrollRepository.addAdjustment(event.storeId, event.periodId, event.data);
      add(LoadPayrollPeriod(storeId: event.storeId, periodId: event.periodId));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onRemoveAdjustment(RemoveAdjustment event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      await _payrollRepository.removeAdjustment(event.storeId, event.periodId, event.adjustmentId);
      add(LoadPayrollPeriod(storeId: event.storeId, periodId: event.periodId));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPayIndividual(PayIndividual event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      await _payrollRepository.payIndividual(event.storeId, event.periodId, event.payrollId);
      add(LoadPayrollPeriod(storeId: event.storeId, periodId: event.periodId));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPayAll(PayAll event, Emitter<PayrollState> emit) async {
    emit(PayrollLoading());
    try {
      await _payrollRepository.payAll(event.storeId, event.periodId);
      add(LoadPayrollPeriod(storeId: event.storeId, periodId: event.periodId));
    } catch (e) {
      emit(PayrollError(mapErrorToUserMessage(e)));
    }
  }
}
