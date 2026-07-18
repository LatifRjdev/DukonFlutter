import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/zakat_payment.dart';

void main() {
  group('ZakatPayment', () {
    ZakatPayment build({
      String id = 'zp-1',
      String storeId = 'store-1',
      double amount = 50,
      double totalAssets = 2000,
      double zakatDue = 50,
      Map<String, dynamic> breakdown = const {},
      String? notes,
      DateTime? paidAt,
      DateTime? createdAt,
    }) =>
        ZakatPayment(
          id: id,
          storeId: storeId,
          amount: amount,
          totalAssets: totalAssets,
          zakatDue: zakatDue,
          breakdown: breakdown,
          notes: notes,
          paidAt: paidAt ?? DateTime.utc(2026, 1, 1),
          createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
        );

    test('notes defaults to null when not provided', () {
      final payment = build();
      expect(payment.notes, isNull);
    });

    test('two instances with the same core fields are equal (Equatable)', () {
      final a = build();
      final b = build();

      expect(a, equals(b));
    });

    test(
        'instances differing only by totalAssets, breakdown, notes or '
        'createdAt still compare equal (all excluded from props)', () {
      final a = build();
      final b = build(
        totalAssets: 999999,
        breakdown: {'inventoryValue': 1},
        notes: 'different notes',
        createdAt: DateTime.utc(2030, 5, 5),
      );

      // NOTE: ZakatPayment.props omits totalAssets/breakdown/notes/createdAt,
      // so this equality holds even though those fields differ. Flagged in
      // report as a possible bug — not fixed per task scope.
      expect(a, equals(b));
    });

    test('instances differing by zakatDue are not equal', () {
      final a = build(zakatDue: 50);
      final b = build(zakatDue: 75);

      expect(a, isNot(equals(b)));
    });

    test('instances differing by id are not equal', () {
      final a = build(id: 'zp-1');
      final b = build(id: 'zp-2');

      expect(a, isNot(equals(b)));
    });

    test('instances differing by paidAt are not equal', () {
      final a = build(paidAt: DateTime.utc(2026, 1, 1));
      final b = build(paidAt: DateTime.utc(2026, 2, 2));

      expect(a, isNot(equals(b)));
    });
  });
}
