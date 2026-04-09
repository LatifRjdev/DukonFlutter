import 'package:equatable/equatable.dart';
import '../../../domain/entities/sale.dart';

abstract class SalesHistoryState extends Equatable {
  const SalesHistoryState();
  @override
  List<Object?> get props => [];
}

class SalesHistoryInitial extends SalesHistoryState {}

class SalesHistoryLoading extends SalesHistoryState {}

class SalesHistoryLoaded extends SalesHistoryState {
  final List<Sale> sales;
  final int total;
  final int totalPages;
  final int currentPage;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? paymentType;
  final bool isLoadingMore;
  final bool isRefunding;

  const SalesHistoryLoaded({
    required this.sales,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.dateFrom,
    this.dateTo,
    this.paymentType,
    this.isLoadingMore = false,
    this.isRefunding = false,
  });

  bool get hasMore => currentPage < totalPages;

  SalesHistoryLoaded copyWith({
    List<Sale>? sales,
    int? total,
    int? totalPages,
    int? currentPage,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? paymentType,
    bool? isLoadingMore,
    bool? isRefunding,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearPaymentType = false,
  }) {
    return SalesHistoryLoaded(
      sales: sales ?? this.sales,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      paymentType: clearPaymentType ? null : (paymentType ?? this.paymentType),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefunding: isRefunding ?? this.isRefunding,
    );
  }

  @override
  List<Object?> get props => [
        sales,
        total,
        totalPages,
        currentPage,
        dateFrom,
        dateTo,
        paymentType,
        isLoadingMore,
        isRefunding,
      ];
}

class SalesHistoryError extends SalesHistoryState {
  final String message;
  const SalesHistoryError(this.message);
  @override
  List<Object?> get props => [message];
}
