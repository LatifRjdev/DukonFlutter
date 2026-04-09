import 'package:equatable/equatable.dart';

class DebtPayment extends Equatable {
  final String id;
  final String saleId;
  final double amount;
  final String method;
  final String? notes;
  final DateTime createdAt;

  const DebtPayment({
    required this.id,
    required this.saleId,
    required this.amount,
    required this.method,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, saleId, amount, method, createdAt];
}
