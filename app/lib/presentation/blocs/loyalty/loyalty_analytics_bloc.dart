import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/loyalty_repository.dart';
import 'loyalty_analytics_event.dart';
import 'loyalty_analytics_state.dart';

class LoyaltyAnalyticsBloc
    extends Bloc<LoyaltyAnalyticsEvent, LoyaltyAnalyticsState> {
  final LoyaltyRepository _repository;

  LoyaltyAnalyticsBloc({required LoyaltyRepository repository})
      : _repository = repository,
        super(const LoyaltyAnalyticsInitial()) {
    on<LoyaltyAnalyticsLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    LoyaltyAnalyticsLoadRequested event,
    Emitter<LoyaltyAnalyticsState> emit,
  ) async {
    emit(const LoyaltyAnalyticsLoading());
    try {
      final data = await _repository.getAnalytics(
        event.storeId,
        event.from,
        event.to,
      );
      emit(LoyaltyAnalyticsLoaded(data));
    } catch (e) {
      emit(LoyaltyAnalyticsError(mapErrorToUserMessage(e)));
    }
  }
}
