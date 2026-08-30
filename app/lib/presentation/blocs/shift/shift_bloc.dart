import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/shift_repository.dart';
import 'shift_event.dart';
import 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final ShiftRepository _shiftRepository;

  ShiftBloc({required ShiftRepository shiftRepository})
      : _shiftRepository = shiftRepository,
        super(ShiftInitial()) {
    on<LoadCurrentShift>(_onLoadCurrentShift);
    on<OpenShift>(_onOpenShift);
    on<CloseShift>(_onCloseShift);
    on<LoadShifts>(_onLoadShifts);
    on<LoadZReport>(_onLoadZReport);
  }

  Future<void> _onLoadCurrentShift(LoadCurrentShift event, Emitter<ShiftState> emit) async {
    // The page dispatches LoadCurrentShift and LoadShifts together, and
    // their handlers run concurrently (no shared transformer). If the
    // other handler has already produced a ShiftLoaded, don't reset the
    // UI to a bare loading spinner and wipe its data out from under it —
    // only show the loading state before anything has loaded yet.
    if (state is! ShiftLoaded) emit(ShiftLoading());
    try {
      final currentShift = await _shiftRepository.getCurrentShift(event.storeId);
      // Preserve whatever history data the other handler has already
      // loaded instead of resetting it.
      final previous = state;
      emit(ShiftLoaded(
        currentShift: currentShift,
        shifts: previous is ShiftLoaded ? previous.shifts : const [],
        total: previous is ShiftLoaded ? previous.total : 0,
        totalPages: previous is ShiftLoaded ? previous.totalPages : 0,
      ));
    } catch (e) {
      emit(ShiftError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onOpenShift(OpenShift event, Emitter<ShiftState> emit) async {
    emit(ShiftLoading());
    try {
      final shift = await _shiftRepository.openShift(
        event.storeId,
        {'openingCash': event.openingCash},
      );
      emit(ShiftOpened(shift));
    } catch (e) {
      emit(ShiftError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onCloseShift(CloseShift event, Emitter<ShiftState> emit) async {
    emit(ShiftLoading());
    try {
      final shift = await _shiftRepository.closeShift(
        event.storeId,
        event.shiftId,
        {'closingCash': event.closingCash},
      );
      emit(ShiftClosed(shift));
    } catch (e) {
      emit(ShiftError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onLoadShifts(LoadShifts event, Emitter<ShiftState> emit) async {
    // See _onLoadCurrentShift — don't clobber a state the other handler
    // already loaded with a bare loading spinner.
    if (state is! ShiftLoaded) emit(ShiftLoading());
    try {
      final result = await _shiftRepository.getShifts(
        event.storeId,
        page: event.page,
        staffId: event.staffId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
      );
      // Preserve the current shift already loaded by the other concurrent
      // handler instead of resetting it.
      final previous = state;
      emit(ShiftLoaded(
        currentShift: previous is ShiftLoaded ? previous.currentShift : null,
        shifts: result.data,
        total: result.total,
        totalPages: result.totalPages,
      ));
    } catch (e) {
      emit(ShiftError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onLoadZReport(LoadZReport event, Emitter<ShiftState> emit) async {
    emit(ShiftLoading());
    try {
      final report = await _shiftRepository.getZReport(event.storeId, event.shiftId);
      emit(ZReportLoaded(report: report));
    } catch (e) {
      emit(ShiftError(mapErrorToUserMessage(e)));
    }
  }
}
