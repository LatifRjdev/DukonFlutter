import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/staff_repository.dart';
import 'staff_event.dart';
import 'staff_state.dart';

class StaffBloc extends Bloc<StaffEvent, StaffState> {
  final StaffRepository _staffRepository;

  StaffBloc({required StaffRepository staffRepository})
      : _staffRepository = staffRepository,
        super(StaffInitial()) {
    on<LoadStaff>(_onLoadStaff);
    on<LoadStaffDetail>(_onLoadStaffDetail);
    on<DeleteStaff>(_onDeleteStaff);
  }

  Future<void> _onLoadStaff(LoadStaff event, Emitter<StaffState> emit) async {
    emit(StaffLoading());
    try {
      final result = await _staffRepository.getStaff(
        event.storeId,
        page: event.page,
        search: event.search,
        role: event.role,
      );
      emit(StaffLoaded(
        staff: result.data,
        total: result.total,
        totalPages: result.totalPages,
      ));
    } catch (e) {
      emit(StaffError(e.toString()));
    }
  }

  Future<void> _onLoadStaffDetail(LoadStaffDetail event, Emitter<StaffState> emit) async {
    emit(StaffLoading());
    try {
      final staffMember = await _staffRepository.getStaffMember(event.storeId, event.id);
      emit(StaffDetailLoaded(staffMember));
    } catch (e) {
      emit(StaffError(e.toString()));
    }
  }

  Future<void> _onDeleteStaff(DeleteStaff event, Emitter<StaffState> emit) async {
    emit(StaffLoading());
    try {
      await _staffRepository.deleteStaff(event.storeId, event.id);
      add(LoadStaff(storeId: event.storeId));
    } catch (e) {
      emit(StaffError(e.toString()));
    }
  }
}
