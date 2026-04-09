import 'package:equatable/equatable.dart';

class ZakatPayment extends Equatable {
  final String id;
  final String storeId;
  final double amount;
  final double totalAssets;
  final double zakatDue;
  final Map<String, dynamic> breakdown;
  final String? notes;
  final DateTime paidAt;
  final DateTime createdAt;

  const ZakatPayment({
    required this.id,
    required this.storeId,
    required this.amount,
    required this.totalAssets,
    required this.zakatDue,
    required this.breakdown,
    this.notes,
    required this.paidAt,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, storeId, amount, zakatDue, paidAt];
}
