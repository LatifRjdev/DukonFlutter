class LoyaltyTransaction {
  final String id;
  final String customerId;
  final String storeId;
  final String type; // EARN | REDEEM | EXPIRE | ADJUST
  final int points;
  final String? saleId;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.type,
    required this.points,
    this.saleId,
    this.expiresAt,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) =>
      LoyaltyTransaction(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        storeId: json['storeId'] as String,
        type: json['type'] as String,
        points: (json['points'] as num).toInt(),
        saleId: json['saleId'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
