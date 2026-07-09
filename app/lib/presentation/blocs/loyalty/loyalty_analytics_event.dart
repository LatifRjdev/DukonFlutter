abstract class LoyaltyAnalyticsEvent {}

class LoyaltyAnalyticsLoadRequested extends LoyaltyAnalyticsEvent {
  final String storeId;
  final DateTime from;
  final DateTime to;

  LoyaltyAnalyticsLoadRequested({
    required this.storeId,
    required this.from,
    required this.to,
  });
}
