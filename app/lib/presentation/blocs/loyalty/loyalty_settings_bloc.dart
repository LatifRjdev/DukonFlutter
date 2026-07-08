import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/loyalty_repository.dart';
import 'loyalty_settings_event.dart';
import 'loyalty_settings_state.dart';

class LoyaltySettingsBloc
    extends Bloc<LoyaltySettingsEvent, LoyaltySettingsState> {
  final LoyaltyRepository _repository;

  LoyaltySettingsBloc({required LoyaltyRepository repository})
      : _repository = repository,
        super(LoyaltySettingsInitial()) {
    on<LoyaltySettingsLoadRequested>(_onLoad);
    on<LoyaltySettingsSaveRequested>(_onSave);
  }

  Future<void> _onLoad(
    LoyaltySettingsLoadRequested event,
    Emitter<LoyaltySettingsState> emit,
  ) async {
    emit(LoyaltySettingsLoading());
    try {
      final settings = await _repository.getSettings(event.storeId);
      emit(LoyaltySettingsLoaded(settings));
    } catch (e) {
      emit(LoyaltySettingsError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSave(
    LoyaltySettingsSaveRequested event,
    Emitter<LoyaltySettingsState> emit,
  ) async {
    emit(LoyaltySettingsLoading());
    try {
      final settings =
          await _repository.updateSettings(event.storeId, event.data);
      emit(LoyaltySettingsSaved(settings));
    } catch (e) {
      emit(LoyaltySettingsError(mapErrorToUserMessage(e)));
    }
  }
}
