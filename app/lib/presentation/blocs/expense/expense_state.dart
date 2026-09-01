import 'package:equatable/equatable.dart';
import '../../../domain/entities/expense.dart';

abstract class ExpenseState extends Equatable {
  const ExpenseState();
  @override
  List<Object?> get props => [];
}

class ExpenseInitial extends ExpenseState {}
class ExpenseLoading extends ExpenseState {}

class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? selectedCategory;
  const ExpenseLoaded({required this.expenses, required this.total, required this.totalPages, this.currentPage = 1, this.selectedCategory});
  @override
  List<Object?> get props => [expenses, total, totalPages, currentPage, selectedCategory];
}

class ExpenseActionSuccess extends ExpenseState {
  final String message;
  const ExpenseActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ExpenseError extends ExpenseState {
  final String message;
  const ExpenseError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Emitted when [ExpenseDeleteRequested] fails.
///
/// Deliberately a distinct type from [ExpenseError]: the list page treats
/// this as a listener-only event (show a snackbar) and skips rebuilding the
/// list around it, so the still-valid [ExpenseLoaded] list — and the
/// expense that failed to delete — are never wiped off the screen while the
/// error is surfaced (SPEC.md #32).
class ExpenseDeleteFailure extends ExpenseState {
  final String message;
  const ExpenseDeleteFailure(this.message);
  @override
  List<Object?> get props => [message];
}
