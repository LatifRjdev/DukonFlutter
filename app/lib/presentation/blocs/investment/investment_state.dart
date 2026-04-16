import 'package:equatable/equatable.dart';
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
  const InvestmentLoaded({required this.investments, required this.total, required this.totalPages, this.currentPage = 1, this.selectedStatus});
  @override
  List<Object?> get props => [investments, total, totalPages, currentPage, selectedStatus];
}

class InvestmentSummaryLoaded extends InvestmentState {
  final InvestmentSummary summary;
  const InvestmentSummaryLoaded(this.summary);
  @override
  List<Object?> get props => [summary];
}

class InvestmentActionSuccess extends InvestmentState {
  final String message;
  const InvestmentActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class InvestmentError extends InvestmentState {
  final String message;
  const InvestmentError(this.message);
  @override
  List<Object?> get props => [message];
}
