import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/zakat_settings.dart';

void main() {
  group('ZakatSettings', () {
    test('has expected defaults when only required fields are provided', () {
      const settings = ZakatSettings(id: 'zs-1', storeId: 'store-1');

      expect(settings.nisabGold, 85);
      expect(settings.nisabSilver, 595);
      expect(settings.nisabCurrency, 'TJS');
      expect(settings.nisabAmount, 0);
      expect(settings.haulStartDate, isNull);
      expect(settings.zakatRate, 2.5);
      expect(settings.includeStock, isTrue);
      expect(settings.includeCash, isTrue);
      expect(settings.includeDebts, isTrue);
      expect(settings.cashOnHand, 0);
    });

    test('two instances with the same core fields are equal (Equatable)', () {
      const a = ZakatSettings(
        id: 'zs-1',
        storeId: 'store-1',
        nisabAmount: 500,
        zakatRate: 2.5,
        cashOnHand: 100,
      );
      const b = ZakatSettings(
        id: 'zs-1',
        storeId: 'store-1',
        nisabAmount: 500,
        zakatRate: 2.5,
        cashOnHand: 100,
      );

      expect(a, equals(b));
    });

    test(
        'instances differing only by nisabGold, nisabSilver, nisabCurrency, '
        'haulStartDate or includeStock/Cash/Debts still compare equal '
        '(all excluded from props)', () {
      const a = ZakatSettings(
        id: 'zs-1',
        storeId: 'store-1',
        nisabAmount: 500,
        zakatRate: 2.5,
        cashOnHand: 100,
      );
      final b = ZakatSettings(
        id: 'zs-1',
        storeId: 'store-1',
        nisabGold: 999,
        nisabSilver: 999,
        nisabCurrency: 'USD',
        nisabAmount: 500,
        haulStartDate: DateTime.utc(2026, 1, 1),
        zakatRate: 2.5,
        includeStock: false,
        includeCash: false,
        includeDebts: false,
        cashOnHand: 100,
      );

      // NOTE: ZakatSettings.props omits nisabGold/nisabSilver/nisabCurrency/
      // haulStartDate/includeStock/includeCash/includeDebts, so this equality
      // holds even though those fields differ. Flagged in report as a
      // possible bug — not fixed per task scope.
      expect(a, equals(b));
    });

    test('instances differing by nisabAmount are not equal', () {
      const a = ZakatSettings(id: 'zs-1', storeId: 'store-1', nisabAmount: 500);
      const b = ZakatSettings(id: 'zs-1', storeId: 'store-1', nisabAmount: 900);

      expect(a, isNot(equals(b)));
    });

    test('instances differing by cashOnHand are not equal', () {
      const a = ZakatSettings(id: 'zs-1', storeId: 'store-1', cashOnHand: 10);
      const b = ZakatSettings(id: 'zs-1', storeId: 'store-1', cashOnHand: 20);

      expect(a, isNot(equals(b)));
    });
  });
}
