import 'package:equatable/equatable.dart';

class FinanceSummary extends Equatable {
  final double totalIncome;
  final double totalCost;
  final double totalExpenses;
  final double profit;
  final int salesCount;
  final double avgCheck;
  final List<TopProduct> topProducts;

  const FinanceSummary({
    required this.totalIncome,
    this.totalCost = 0,
    required this.totalExpenses,
    required this.profit,
    required this.salesCount,
    required this.avgCheck,
    this.topProducts = const [],
  });

  /// Revenue less cost of goods sold. NOT less expenses — that is net.
  double get grossProfit => totalIncome - totalCost;

  /// Gross profit less operating expenses. Expenses are subtracted here and
  /// nowhere else; the screen previously subtracted them a second time on top
  /// of a `profit` that already included them.
  double get netProfit => grossProfit - totalExpenses;

  @override
  List<Object?> get props =>
      [totalIncome, totalCost, totalExpenses, profit, salesCount];
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
