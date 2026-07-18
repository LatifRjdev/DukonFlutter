import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/zakat_calculation.dart';

void main() {
  group('ZakatCalculation', () {
    test('zakatRate defaults to 2.5 when not provided', () {
      const calc = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: true,
      );

      expect(calc.zakatRate, 2.5);
    });

    test('two instances with the same core fields are equal (Equatable)', () {
      const a = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: true,
      );
      const b = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: true,
      );

      expect(a, equals(b));
    });

    test(
        'instances differing only by receivables, payables or nisabAmount '
        'still compare equal (all three excluded from props)', () {
      const a = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: true,
      );
      const b = ZakatCalculation(
        stockValue: 1000,
        receivables: 999,
        payables: 999,
        netAssets: 1100,
        nisabAmount: 999,
        zakatDue: 27.5,
        isAboveNisab: true,
      );

      // NOTE: ZakatCalculation.props omits receivables/payables/nisabAmount,
      // so this equality holds even though the breakdown values differ.
      // Flagged in report as a possible bug — not fixed per task scope.
      expect(a, equals(b));
    });

    test('instances differing by zakatDue are not equal', () {
      const a = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: true,
      );
      const b = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 40,
        isAboveNisab: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('instances differing by isAboveNisab are not equal', () {
      const a = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: true,
      );
      const b = ZakatCalculation(
        stockValue: 1000,
        receivables: 200,
        payables: 100,
        netAssets: 1100,
        nisabAmount: 500,
        zakatDue: 27.5,
        isAboveNisab: false,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
