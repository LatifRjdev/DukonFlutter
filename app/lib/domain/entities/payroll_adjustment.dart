import 'package:equatable/equatable.dart';

class PayrollAdjustment extends Equatable {
  final String id;
  final String type; // BONUS or DEDUCTION
  final double amount;
  final String description;
  final DateTime? date;

  const PayrollAdjustment({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.date,
  });

  factory PayrollAdjustment.fromJson(Map<String, dynamic> json) {
    return PayrollAdjustment(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, description];
}
