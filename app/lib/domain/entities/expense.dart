import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String storeId;
  final String category; // ExpenseCategory enum as string
  final double amount;
  final String? description;
  final String? notes;
  final String? receiptUrl;
  final bool isRecurring;
  final int? recurringDay;
  final String? createdBy;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.storeId,
    required this.category,
    required this.amount,
    this.description,
    this.notes,
    this.receiptUrl,
    this.isRecurring = false,
    this.recurringDay,
    this.createdBy,
    required this.date,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, storeId, category, amount, date];
}
