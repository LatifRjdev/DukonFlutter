import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/zakat_repository.dart';
import 'zakat_event.dart';
import 'zakat_state.dart';

class ZakatBloc extends Bloc<ZakatEvent, ZakatState> {
  final ZakatRepository _zakatRepository;

  ZakatBloc({required ZakatRepository zakatRepository})
      : _zakatRepository = zakatRepository,
        super(ZakatInitial()) {
    on<ZakatCalculateRequested>(_onCalculate);
    on<ZakatSettingsRequested>(_onSettingsRequested);
    on<ZakatSettingsUpdated>(_onSettingsUpdated);
    on<ZakatPaymentSubmitted>(_onPaymentSubmitted);
    on<ZakatPaymentsRequested>(_onPaymentsRequested);
  }

  Future<void> _onCalculate(ZakatCalculateRequested event, Emitter<ZakatState> emit) async {
    emit(ZakatLoading());
    try {
      final calculation = await _zakatRepository.calculate(event.storeId);
      final settings = await _zakatRepository.getSettings(event.storeId);
      emit(ZakatCalculated(calculation: calculation, settings: settings));
    } catch (e) {
      emit(ZakatError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSettingsRequested(ZakatSettingsRequested event, Emitter<ZakatState> emit) async {
    emit(ZakatLoading());
    try {
      final settings = await _zakatRepository.getSettings(event.storeId);
      if (settings != null) {
        emit(ZakatSettingsLoaded(settings));
      } else {
        emit(ZakatInitial());
      }
    } catch (e) {
      emit(ZakatError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSettingsUpdated(ZakatSettingsUpdated event, Emitter<ZakatState> emit) async {
    emit(ZakatLoading());
    try {
      await _zakatRepository.upsertSettings(event.storeId, event.data);
      emit(const ZakatActionSuccess('Настройки закята сохранены'));
    } catch (e) {
      emit(ZakatError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPaymentSubmitted(ZakatPaymentSubmitted event, Emitter<ZakatState> emit) async {
    emit(ZakatLoading());
    try {
      await _zakatRepository.createPayment(event.storeId, event.data);
      emit(const ZakatActionSuccess('Выплата закята записана'));
    } catch (e) {
      emit(ZakatError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPaymentsRequested(ZakatPaymentsRequested event, Emitter<ZakatState> emit) async {
    // Spec E B.1: only show the spinner on the initial fetch.
    // Load-more (page > 1) keeps the existing list visible while
    // appending — otherwise the screen would flash empty between
    // pages, which is jarring UX.
    final current = state;
    final isAppend = event.page > 1 && current is ZakatPaymentsLoaded;
    if (!isAppend) emit(ZakatLoading());
    try {
      final result = await _zakatRepository.getPayments(
        event.storeId,
        page: event.page,
        limit: event.limit,
      );
      final merged = isAppend
          ? [...current.payments, ...result.data]
          : result.data;
      emit(ZakatPaymentsLoaded(
        merged,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: result.currentPage,
      ));
    } catch (e) {
      emit(ZakatError(mapErrorToUserMessage(e)));
    }
  }
}
