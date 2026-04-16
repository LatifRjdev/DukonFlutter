import 'package:equatable/equatable.dart';

class Investment extends Equatable {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final double amount;
  final double? returnAmount;
  final String investorName;
  final String? investorPhone;
  final String status; // ACTIVE, COMPLETED, CANCELLED
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  const Investment({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.amount,
    this.returnAmount,
    required this.investorName,
    this.investorPhone,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, storeId, name, amount, status];
}

class InvestmentSummary extends Equatable {
  final double totalAmount;
  final int totalCount;
  final double activeAmount;
  final int activeCount;
  final double completedAmount;
  final double completedReturnAmount;
  final int completedCount;

  const InvestmentSummary({
    required this.totalAmount,
    required this.totalCount,
    required this.activeAmount,
    required this.activeCount,
    required this.completedAmount,
    required this.completedReturnAmount,
    required this.completedCount,
  });

  @override
  List<Object?> get props => [totalAmount, totalCount, activeCount];
}
