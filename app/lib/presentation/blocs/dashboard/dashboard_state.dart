import 'package:equatable/equatable.dart';
import '../../../domain/entities/sale.dart';

class DashboardStats extends Equatable {
  final double todayRevenue;
  final double todayCost;
  final double todayExpenses;
  final double todayProfit;
  final int todaySalesCount;
  final int totalProducts;
  final int lowStockProducts;
  final double customerDebtsTotal;
  final double supplierDebtsTotal;
  final List<Sale> recentSales;

  const DashboardStats({
    this.todayRevenue = 0,
    this.todayCost = 0,
    this.todayExpenses = 0,
    this.todayProfit = 0,
    this.todaySalesCount = 0,
    this.totalProducts = 0,
    this.lowStockProducts = 0,
    this.customerDebtsTotal = 0,
    this.supplierDebtsTotal = 0,
    this.recentSales = const [],
  });

  @override
  List<Object?> get props => [
    todayRevenue, todayCost, todayExpenses, todayProfit,
    todaySalesCount, totalProducts, lowStockProducts,
    customerDebtsTotal, supplierDebtsTotal, recentSales,
  ];
}

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final String period;
  const DashboardLoaded(this.stats, {this.period = 'today'});
  @override
  List<Object?> get props => [stats, period];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}
