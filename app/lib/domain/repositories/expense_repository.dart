import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<({List<Expense> data, int total, int totalPages})> getExpenses(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  });
  Future<Expense> getExpense(String storeId, String id);
  Future<Expense> createExpense(String storeId, Map<String, dynamic> data);
  Future<Expense> updateExpense(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteExpense(String storeId, String id);
}
