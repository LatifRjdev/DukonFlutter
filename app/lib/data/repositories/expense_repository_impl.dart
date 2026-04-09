import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/remote/expense_remote_datasource.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseRemoteDatasource _remoteDatasource;

  ExpenseRepositoryImpl({required ExpenseRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<({List<Expense> data, int total, int totalPages})> getExpenses(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) {
    return _remoteDatasource.getExpenses(
      storeId,
      page: page,
      limit: limit,
      category: category,
      startDate: startDate,
      endDate: endDate,
      search: search,
    );
  }

  @override
  Future<Expense> getExpense(String storeId, String id) {
    return _remoteDatasource.getExpense(storeId, id);
  }

  @override
  Future<Expense> createExpense(String storeId, Map<String, dynamic> data) {
    return _remoteDatasource.createExpense(storeId, data);
  }

  @override
  Future<Expense> updateExpense(String storeId, String id, Map<String, dynamic> data) {
    return _remoteDatasource.updateExpense(storeId, id, data);
  }

  @override
  Future<void> deleteExpense(String storeId, String id) {
    return _remoteDatasource.deleteExpense(storeId, id);
  }
}
