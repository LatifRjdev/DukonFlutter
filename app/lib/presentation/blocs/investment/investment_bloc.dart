import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/investment_repository.dart';
import 'investment_event.dart';
import 'investment_state.dart';

class InvestmentBloc extends Bloc<InvestmentEvent, InvestmentState> {
  final InvestmentRepository _investmentRepository;

  InvestmentBloc({required InvestmentRepository investmentRepository})
      : _investmentRepository = investmentRepository,
        super(InvestmentInitial()) {
    on<InvestmentListRequested>(_onListRequested);
    on<InvestmentSummaryRequested>(_onSummaryRequested);
    on<InvestmentCreateRequested>(_onCreateRequested);
    on<InvestmentUpdateRequested>(_onUpdateRequested);
    on<InvestmentDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onListRequested(InvestmentListRequested event, Emitter<InvestmentState> emit) async {
    // Spec E D.1: avoid Loading flicker on filter switch by reusing
    // the previous Loaded state with isRefreshing=true.
    final prevState = state;
    if (prevState is InvestmentLoaded) {
      emit(prevState.copyWith(isRefreshing: true));
    } else {
      emit(InvestmentLoading());
    }
    try {
      final result = await _investmentRepository.getInvestments(
        event.storeId,
        page: event.page,
        status: event.status,
      );
      emit(InvestmentLoaded(
        investments: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        selectedStatus: event.status,
        isRefreshing: false,
      ));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSummaryRequested(InvestmentSummaryRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      final summary = await _investmentRepository.getSummary(event.storeId);
      emit(InvestmentSummaryLoaded(summary));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onCreateRequested(InvestmentCreateRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      await _investmentRepository.createInvestment(event.storeId, event.data);
      emit(const InvestmentActionSuccess('Вложение добавлено'));
      // Spec E D.2: yield to event loop so BlocBuilder consumers see
      // the success state before it's overwritten by the chained reload.
      await Future<void>.delayed(Duration.zero);
      add(InvestmentListRequested(storeId: event.storeId));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onUpdateRequested(InvestmentUpdateRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      await _investmentRepository.updateInvestment(event.storeId, event.id, event.data);
      emit(const InvestmentActionSuccess('Вложение обновлено'));
      // Spec E D.2: yield to event loop so BlocBuilder consumers see
      // the success state before it's overwritten by the chained reload.
      await Future<void>.delayed(Duration.zero);
      add(InvestmentListRequested(storeId: event.storeId));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onDeleteRequested(InvestmentDeleteRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      await _investmentRepository.deleteInvestment(event.storeId, event.id);
      emit(const InvestmentActionSuccess('Вложение удалено'));
      // Spec E D.2: yield to event loop so BlocBuilder consumers see
      // the success state before it's overwritten by the chained reload.
      await Future<void>.delayed(Duration.zero);
      add(InvestmentListRequested(storeId: event.storeId));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }
}
