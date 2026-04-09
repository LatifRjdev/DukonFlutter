import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/expense_repository.dart';
import 'expense_event.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository _expenseRepository;

  ExpenseBloc({required ExpenseRepository expenseRepository})
      : _expenseRepository = expenseRepository,
        super(ExpenseInitial()) {
    on<ExpenseListRequested>(_onListRequested);
    on<ExpenseCreateRequested>(_onCreateRequested);
    on<ExpenseUpdateRequested>(_onUpdateRequested);
    on<ExpenseDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onListRequested(ExpenseListRequested event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      final result = await _expenseRepository.getExpenses(
        event.storeId,
        page: event.page,
        category: event.category,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(ExpenseLoaded(
        expenses: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        selectedCategory: event.category,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onCreateRequested(ExpenseCreateRequested event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.createExpense(event.storeId, event.data);
      emit(const ExpenseActionSuccess('Расход добавлен'));
      add(ExpenseListRequested(storeId: event.storeId));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onUpdateRequested(ExpenseUpdateRequested event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.updateExpense(event.storeId, event.id, event.data);
      emit(const ExpenseActionSuccess('Расход обновлён'));
      add(ExpenseListRequested(storeId: event.storeId));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onDeleteRequested(ExpenseDeleteRequested event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.deleteExpense(event.storeId, event.id);
      emit(const ExpenseActionSuccess('Расход удалён'));
      add(ExpenseListRequested(storeId: event.storeId));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }
}
