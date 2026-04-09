import 'package:flutter_bloc/flutter_bloc.dart';
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
    emit(ShiftLoading());
    try {
      final currentShift = await _shiftRepository.getCurrentShift(event.storeId);
      emit(ShiftLoaded(currentShift: currentShift));
    } catch (e) {
      emit(ShiftError(e.toString()));
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
      emit(ShiftError(e.toString()));
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
      emit(ShiftError(e.toString()));
    }
  }

  Future<void> _onLoadShifts(LoadShifts event, Emitter<ShiftState> emit) async {
    emit(ShiftLoading());
    try {
      final result = await _shiftRepository.getShifts(
        event.storeId,
        page: event.page,
        staffId: event.staffId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
      );
      emit(ShiftLoaded(
        shifts: result.data,
        total: result.total,
        totalPages: result.totalPages,
      ));
    } catch (e) {
      emit(ShiftError(e.toString()));
    }
  }

  Future<void> _onLoadZReport(LoadZReport event, Emitter<ShiftState> emit) async {
    emit(ShiftLoading());
    try {
      final report = await _shiftRepository.getZReport(event.storeId, event.shiftId);
      emit(ZReportLoaded(report: report));
    } catch (e) {
      emit(ShiftError(e.toString()));
    }
  }
}
