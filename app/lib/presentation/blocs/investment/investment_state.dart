import 'package:equatable/equatable.dart';
import '../../../core/errors/app_message.dart';
import '../../../domain/entities/investment.dart';

abstract class InvestmentState extends Equatable {
  const InvestmentState();
  @override
  List<Object?> get props => [];
}

class InvestmentInitial extends InvestmentState {}
class InvestmentLoading extends InvestmentState {}

class InvestmentLoaded extends InvestmentState {
  final List<Investment> investments;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? selectedStatus;
  final bool isRefreshing;
  const InvestmentLoaded({
    required this.investments,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.selectedStatus,
    this.isRefreshing = false,
  });

  InvestmentLoaded copyWith({
    List<Investment>? investments,
    int? total,
    int? totalPages,
    int? currentPage,
    String? selectedStatus,
    bool? isRefreshing,
  }) {
    return InvestmentLoaded(
      investments: investments ?? this.investments,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [investments, total, totalPages, currentPage, selectedStatus, isRefreshing];
}

class InvestmentSummaryLoaded extends InvestmentState {
  final InvestmentSummary summary;
  const InvestmentSummaryLoaded(this.summary);
  @override
  List<Object?> get props => [summary];
}

class InvestmentActionSuccess extends InvestmentState {
  final AppMessage message;
  const InvestmentActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class InvestmentError extends InvestmentState {
  final AppMessage message;
  const InvestmentError(this.message);
  @override
  List<Object?> get props => [message];
}
