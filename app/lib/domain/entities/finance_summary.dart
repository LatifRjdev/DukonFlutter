import 'package:equatable/equatable.dart';

class FinanceSummary extends Equatable {
  final double totalIncome;
  final double totalExpenses;
  final double profit;
  final int salesCount;
  final double avgCheck;
  final List<TopProduct> topProducts;

  const FinanceSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.profit,
    required this.salesCount,
    required this.avgCheck,
    this.topProducts = const [],
  });

  @override
  List<Object?> get props => [totalIncome, totalExpenses, profit, salesCount];
}

class TopProduct extends Equatable {
  final String id;
  final String name;
  final int quantity;
  final double revenue;

  const TopProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  @override
  List<Object?> get props => [id, name, quantity, revenue];
}
