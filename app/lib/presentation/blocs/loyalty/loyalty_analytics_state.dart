import 'package:equatable/equatable.dart';
import '../../../domain/entities/loyalty_analytics.dart';

abstract class LoyaltyAnalyticsState extends Equatable {
  const LoyaltyAnalyticsState();
  @override
  List<Object?> get props => [];
}

class LoyaltyAnalyticsInitial extends LoyaltyAnalyticsState {
  const LoyaltyAnalyticsInitial();
}

class LoyaltyAnalyticsLoading extends LoyaltyAnalyticsState {
  const LoyaltyAnalyticsLoading();
}

class LoyaltyAnalyticsLoaded extends LoyaltyAnalyticsState {
  final LoyaltyAnalytics data;
  const LoyaltyAnalyticsLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class LoyaltyAnalyticsError extends LoyaltyAnalyticsState {
  final String message;
  const LoyaltyAnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
