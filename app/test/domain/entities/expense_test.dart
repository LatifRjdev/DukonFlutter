import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/expense.dart';

void main() {
  group('Expense', () {
    Expense buildExpense({
      String id = 'exp-1',
      String storeId = 'store-1',
      String category = 'RENT',
      double amount = 100,
      String? description,
      String? notes,
      String? receiptUrl,
      bool isRecurring = false,
      int? recurringDay,
      String? createdBy,
      DateTime? date,
      DateTime? createdAt,
    }) {
      return Expense(
        id: id,
        storeId: storeId,
        category: category,
        amount: amount,
        description: description,
        notes: notes,
        receiptUrl: receiptUrl,
        isRecurring: isRecurring,
        recurringDay: recurringDay,
        createdBy: createdBy,
        date: date ?? DateTime(2026, 1, 1),
        createdAt: createdAt ?? DateTime(2026, 1, 1),
      );
    }

    test('defaults isRecurring to false and optional fields to null', () {
      final expense = buildExpense();

      expect(expense.isRecurring, isFalse);
      expect(expense.recurringDay, isNull);
      expect(expense.description, isNull);
      expect(expense.notes, isNull);
      expect(expense.receiptUrl, isNull);
      expect(expense.createdBy, isNull);
    });

    test('two expenses with same id/storeId/category/amount/date are equal '
        'even when description/notes differ (props excludes them)', () {
      final date = DateTime(2026, 3, 5);
      final a = buildExpense(date: date, description: 'Rent for March');
      final b = buildExpense(date: date, description: 'Something else');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('expenses with different amounts are not equal', () {
      final a = buildExpense(amount: 100);
      final b = buildExpense(amount: 200);

      expect(a, isNot(equals(b)));
    });

    test('expenses with different ids are not equal', () {
      final a = buildExpense(id: 'exp-1');
      final b = buildExpense(id: 'exp-2');

      expect(a, isNot(equals(b)));
    });

    test('retains isRecurring and recurringDay when provided', () {
      final expense = buildExpense(isRecurring: true, recurringDay: 15);

      expect(expense.isRecurring, isTrue);
      expect(expense.recurringDay, 15);
    });
  });
}
