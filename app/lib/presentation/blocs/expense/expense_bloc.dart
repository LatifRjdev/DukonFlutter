import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
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
      emit(ExpenseError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onCreateRequested(ExpenseCreateRequested event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.createExpense(event.storeId, event.data);
      emit(const ExpenseActionSuccess('Расход добавлен'));
      add(ExpenseListRequested(storeId: event.storeId));
    } catch (e) {
      emit(ExpenseError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onUpdateRequested(ExpenseUpdateRequested event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.updateExpense(event.storeId, event.id, event.data);
      emit(const ExpenseActionSuccess('Расход обновлён'));
      add(ExpenseListRequested(storeId: event.storeId));
    } catch (e) {
      emit(ExpenseError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onDeleteRequested(ExpenseDeleteRequested event, Emitter<ExpenseState> emit) async {
    // Deliberately no leading `emit(ExpenseLoading())` here (unlike the
    // other handlers above): emitting it would replace the currently
    // displayed ExpenseLoaded list with a spinner before the delete call
    // has even resolved, and if the call then fails there'd be nothing to
    // restore the list from. Skipping it keeps the list — and the item
    // being deleted — on screen until the outcome is known (SPEC.md #32).
    try {
      await _expenseRepository.deleteExpense(event.storeId, event.id);
      emit(const ExpenseActionSuccess('Расход удалён'));
      add(ExpenseListRequested(storeId: event.storeId));
    } catch (e) {
      emit(ExpenseDeleteFailure(mapErrorToUserMessage(e)));
    }
  }
}
