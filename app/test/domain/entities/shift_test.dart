import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/shift.dart';

void main() {
  group('ShiftModel.fromJson', () {
    test('parses a full open-shift response with all fields present', () {
      final shift = ShiftModel.fromJson({
        'id': 'shift-1',
        'storeId': 'store-1',
        'staffId': 'staff-1',
        'staffName': 'Ali',
        'openedAt': '2026-07-17T08:00:00.000Z',
        'closedAt': '2026-07-17T20:00:00.000Z',
        'openingCash': 500,
        'closingCash': 1200,
        'expectedCash': 1250,
        'difference': -50,
        'salesTotal': 3000,
        'salesCount': 42,
        'cashSales': 750,
        'cardSales': 2000,
        'debtSales': 250,
        'returnsTotal': 100,
        'returnsCount': 2,
        'status': 'CLOSED',
        'notes': 'End of day',
      });

      expect(shift.id, 'shift-1');
      expect(shift.storeId, 'store-1');
      expect(shift.staffId, 'staff-1');
      expect(shift.staffName, 'Ali');
      expect(shift.openedAt, DateTime.parse('2026-07-17T08:00:00.000Z'));
      expect(shift.closedAt, DateTime.parse('2026-07-17T20:00:00.000Z'));
      expect(shift.openingCash, 500);
      expect(shift.closingCash, 1200);
      expect(shift.expectedCash, 1250);
      expect(shift.difference, -50);
      expect(shift.salesTotal, 3000);
      expect(shift.salesCount, 42);
      expect(shift.cashSales, 750);
      expect(shift.cardSales, 2000);
      expect(shift.debtSales, 250);
      expect(shift.returnsTotal, 100);
      expect(shift.returnsCount, 2);
      expect(shift.status, 'CLOSED');
      expect(shift.notes, 'End of day');
    });

    test(
        'defaults optional numeric fields to 0 and nullable fields to null '
        'for a freshly-opened shift', () {
      final shift = ShiftModel.fromJson({
        'id': 'shift-2',
        'storeId': 'store-1',
        'staffId': 'staff-1',
        'openedAt': '2026-07-17T08:00:00.000Z',
        'openingCash': 500,
        'status': 'OPEN',
      });

      expect(shift.staffName, isNull);
      expect(shift.closedAt, isNull);
      expect(shift.closingCash, isNull);
      expect(shift.expectedCash, isNull);
      expect(shift.difference, isNull);
      expect(shift.salesTotal, 0);
      expect(shift.salesCount, 0);
      expect(shift.cashSales, 0);
      expect(shift.cardSales, 0);
      expect(shift.debtSales, 0);
      expect(shift.returnsTotal, 0);
      expect(shift.returnsCount, 0);
      expect(shift.notes, isNull);
    });

    test('accepts integer JSON numbers for double fields', () {
      final shift = ShiftModel.fromJson({
        'id': 'shift-3',
        'storeId': 'store-1',
        'staffId': 'staff-1',
        'openedAt': '2026-07-17T08:00:00.000Z',
        'openingCash': 500, // int, not double
        'status': 'OPEN',
      });

      expect(shift.openingCash, isA<double>());
      expect(shift.openingCash, 500.0);
    });
  });

  group('ShiftModel equality (Equatable props)', () {
    ShiftModel build({String status = 'OPEN', double openingCash = 500}) =>
        ShiftModel(
          id: 'shift-1',
          storeId: 'store-1',
          staffId: 'staff-1',
          openedAt: DateTime(2026, 7, 17),
          openingCash: openingCash,
          status: status,
        );

    test('two shifts with the same id/storeId/staffId/status are equal '
        'even if other fields differ', () {
      final a = build(openingCash: 500);
      final b = build(openingCash: 999);
      expect(a, equals(b));
    });

    test('shifts with different status are not equal', () {
      final a = build(status: 'OPEN');
      final b = build(status: 'CLOSED');
      expect(a, isNot(equals(b)));
    });
  });
}
