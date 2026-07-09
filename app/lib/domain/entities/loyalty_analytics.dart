class LoyaltyAnalyticsTopCustomer {
  final String customerId;
  final String name;
  final int balance;
  final int totalEarned;

  const LoyaltyAnalyticsTopCustomer({
    required this.customerId,
    required this.name,
    required this.balance,
    required this.totalEarned,
  });
}

class LoyaltyAnalytics {
  final DateTime from;
  final DateTime to;
  final int totalEarned;
  final int totalRedeemed;
  final int totalExpired;
  final double discountValue;
  final int activeParticipants;
  final List<LoyaltyAnalyticsTopCustomer> topCustomers;

  const LoyaltyAnalytics({
    required this.from,
    required this.to,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.totalExpired,
    required this.discountValue,
    required this.activeParticipants,
    required this.topCustomers,
  });

  factory LoyaltyAnalytics.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    final tops = (json['topCustomers'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((c) => LoyaltyAnalyticsTopCustomer(
              customerId: c['customerId'] as String,
              name: c['name'] as String,
              balance: (c['balance'] as num).toInt(),
              totalEarned: (c['totalEarned'] as num).toInt(),
            ))
        .toList();
    return LoyaltyAnalytics(
      from: DateTime.parse(period['from'] as String),
      to: DateTime.parse(period['to'] as String),
      totalEarned: (json['totalEarned'] as num).toInt(),
      totalRedeemed: (json['totalRedeemed'] as num).toInt(),
      totalExpired: (json['totalExpired'] as num).toInt(),
      discountValue: (json['discountValue'] as num).toDouble(),
      activeParticipants: (json['activeParticipants'] as num).toInt(),
      topCustomers: tops,
    );
  }
}
