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
  final String? status;
  final bool isLoadingMore;
  final bool isRefunding;
  final String? refundError;
  final int skippedRows;

  const SalesHistoryLoaded({
    required this.sales,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.dateFrom,
    this.dateTo,
    this.paymentType,
    this.status,
    this.isLoadingMore = false,
    this.isRefunding = false,
    this.refundError,
    this.skippedRows = 0,
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
    String? status,
    bool? isLoadingMore,
    bool? isRefunding,
    String? refundError,
    int? skippedRows,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearPaymentType = false,
    bool clearStatus = false,
    bool clearRefundError = false,
  }) {
    return SalesHistoryLoaded(
      sales: sales ?? this.sales,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      paymentType: clearPaymentType ? null : (paymentType ?? this.paymentType),
      status: clearStatus ? null : (status ?? this.status),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefunding: isRefunding ?? this.isRefunding,
      refundError: clearRefundError ? null : (refundError ?? this.refundError),
      skippedRows: skippedRows ?? this.skippedRows,
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
        status,
        isLoadingMore,
        isRefunding,
        refundError,
        skippedRows,
      ];
}

class SalesHistoryError extends SalesHistoryState {
  final String message;
  const SalesHistoryError(this.message);
  @override
  List<Object?> get props => [message];
}
