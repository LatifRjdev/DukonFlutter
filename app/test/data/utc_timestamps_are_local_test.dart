// Regression guard for the systematic timezone defect: the API serialises every
// timestamp as UTC ISO-8601 ("2026-10-02T08:57:27.332Z"). `DateTime.parse` on
// such a string returns a DateTime with `isUtc == true`, and `DateFormat` prints
// the *UTC* wall-clock for it. Tajikistan is UTC+05, so a sale rung up at 13:57
// rendered as 08:57, and anything between 00:00 and 05:00 local rendered with
// the previous day's date.
//
// The fix converts at the parse boundary (`.toLocal()` in the data layer and in
// the handful of pages that read a Dio response directly), so presentation code
// receives an already-local DateTime.
//
// These assertions are deliberately computed from the same instant rather than
// hardcoded, so they hold in any CI timezone. The load-bearing, zone-independent
// assertion is `isUtc == false`: `.toLocal()` clears that flag even when the
// host happens to run in UTC, so dropping the fix fails this suite everywhere.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:dukonpro/data/models/sale_model.dart';
import 'package:dukonpro/data/models/stock_movement_model.dart';
import 'package:dukonpro/data/models/store_model.dart';
import 'package:dukonpro/data/models/user_model.dart';
import 'package:dukonpro/domain/entities/shift.dart';

/// The instant from the verified device report: `/finances/balance` returned
/// this for a sale and the Баланс screen rendered "02.10.2026 08:57".
const _saleIso = '2026-10-02T08:57:27.332Z';

/// 22:30 UTC — the local date is the *next* day in every zone east of UTC.
const _lateEveningIso = '2026-10-02T22:30:00.000Z';

/// 01:30 UTC — the local date is the *previous* day in every zone west of UTC.
const _earlyMorningIso = '2026-10-02T01:30:00.000Z';

final _dateTime = DateFormat('dd.MM.yyyy HH:mm');

Map<String, dynamic> _saleJson(String createdAt) => {
      'id': 's1',
      'storeId': 'store1',
      'receiptNo': '0001',
      'subtotal': 100,
      'total': 100,
      'paymentType': 'CASH',
      'paidAmount': 100,
      'createdAt': createdAt,
    };

Map<String, dynamic> _saleMap(String createdAt) => {
      'id': 's1',
      'store_id': 'store1',
      'receipt_no': '0001',
      'subtotal': 100,
      'total': 100,
      'payment_type': 'CASH',
      'paid_amount': 100,
      'created_at': createdAt,
    };

void main() {
  group('UTC timestamps from the API', () {
    test('should yield a local DateTime when a sale is mapped from API JSON',
        () {
      final sale = SaleModel.fromJson(_saleJson(_saleIso));

      expect(sale.createdAt.isUtc, isFalse,
          reason: 'presentation must receive an already-local DateTime');
      // Same instant, different wall-clock representation.
      expect(sale.createdAt.isAtSameMomentAs(DateTime.parse(_saleIso)), isTrue);
    });

    test('should yield a local DateTime when a sale is mapped from the local DB',
        () {
      // Rows cached before this fix were written from UTC DateTimes, so they
      // still carry the trailing Z and need converting on the way back out.
      final sale = SaleModel.fromMap(_saleMap(_saleIso));

      expect(sale.createdAt.isUtc, isFalse);
      expect(sale.createdAt.isAtSameMomentAs(DateTime.parse(_saleIso)), isTrue);
    });

    test('should yield a local DateTime when a nullable timestamp is present',
        () {
      final sale = SaleModel.fromJson(
          _saleJson(_saleIso)..['dueDate'] = _lateEveningIso);

      expect(sale.dueDate, isNotNull);
      expect(sale.dueDate!.isUtc, isFalse);
      // checkout_bloc sends dueDate as `.toUtc().toIso8601String()`, so a
      // date picked at local midnight comes back as the previous day in UTC.
      // Reading it without .toLocal() is what made the due date render a day
      // early; this asserts the round trip is symmetric.
      expect(sale.dueDate!.isAtSameMomentAs(DateTime.parse(_lateEveningIso)),
          isTrue);
    });

    test('should yield local DateTimes when other representative mappers run',
        () {
      expect(
        UserModel.fromJson({
          'id': 'u1',
          'phone': '+992900000000',
          'name': 'Тест',
          'createdAt': _saleIso,
        }).createdAt.isUtc,
        isFalse,
      );

      expect(
        StoreModel.fromJson({
          'id': 'st1',
          'ownerId': 'u1',
          'name': 'Дукон',
          'category': 'GROCERY',
          'createdAt': _saleIso,
        }).createdAt.isUtc,
        isFalse,
      );

      expect(
        StockMovementModel.fromJson({
          'id': 'm1',
          'storeId': 'store1',
          'productId': 'p1',
          'type': 'IN',
          'quantity': 5,
          'createdAt': _saleIso,
        }).createdAt.isUtc,
        isFalse,
      );

      final shift = ShiftModel.fromJson({
        'id': 'sh1',
        'storeId': 'store1',
        'staffId': 'stf1',
        'openedAt': _saleIso,
        'closedAt': _lateEveningIso,
        'openingCash': 0,
        'status': 'CLOSED',
      });
      expect(shift.openedAt.isUtc, isFalse);
      expect(shift.closedAt!.isUtc, isFalse);
    });
  });

  group('rendered output', () {
    test('should match the local wall-clock when a UTC instant is formatted',
        () {
      final sale = SaleModel.fromJson(_saleJson(_saleIso));

      // Expectation derived from the same instant, so this holds under any
      // host timezone rather than baking in UTC+05.
      final expected = _dateTime.format(DateTime.parse(_saleIso).toLocal());
      expect(_dateTime.format(sale.createdAt), expected);
    });

    test(
        'should print a different wall-clock than the raw UTC string when the '
        'host is not on UTC', () {
      final sale = SaleModel.fromJson(_saleJson(_saleIso));
      final rawUtc = DateTime.parse(_saleIso);

      // DateTime.timeZoneOffset is ALWAYS zero on an isUtc instance, so
      // asking rawUtc would have skipped this assertion on every host,
      // including UTC+05. The host's own offset is the real discriminator.
      if (DateTime.now().timeZoneOffset == Duration.zero) {
        // A UTC host cannot distinguish the two renderings; the isUtc
        // assertions above are what carry the contract there.
        return;
      }
      expect(_dateTime.format(sale.createdAt),
          isNot(_dateTime.format(rawUtc)),
          reason: 'formatting the UTC DateTime is the original defect');
    });
  });

  group('day boundaries', () {
    // The nastiest symptom: the *date* is wrong, not just the time.
    test('should roll the date forward when a UTC evening is local tomorrow',
        () {
      final sale = SaleModel.fromJson(_saleJson(_lateEveningIso));
      final rawUtc = DateTime.parse(_lateEveningIso);

      expect(_dateTime.format(sale.createdAt),
          _dateTime.format(rawUtc.toLocal()));

      if (DateTime.now().timeZoneOffset >
          const Duration(hours: 1, minutes: 30)) {
        // e.g. Dushanbe (UTC+05): 02.10 22:30Z is 03.10 03:30 local.
        expect(sale.createdAt.day, isNot(rawUtc.day),
            reason: 'east of UTC a late-evening UTC instant is local tomorrow');
      }
    });

    test('should roll the date back when a UTC early morning is local yesterday',
        () {
      final sale = SaleModel.fromJson(_saleJson(_earlyMorningIso));
      final rawUtc = DateTime.parse(_earlyMorningIso);

      expect(_dateTime.format(sale.createdAt),
          _dateTime.format(rawUtc.toLocal()));

      if (DateTime.now().timeZoneOffset <
          const Duration(hours: -1, minutes: -30)) {
        expect(sale.createdAt.day, isNot(rawUtc.day),
            reason: 'west of UTC an early-morning UTC instant is local '
                'yesterday');
      }
    });

    test(
        'should keep the local date when a Dushanbe-morning sale crosses '
        'midnight UTC', () {
      // 02:30 local in Dushanbe on 03.10 is 21:30Z on 02.10 — the case that
      // made the Баланс screen show a sale under the wrong day's header.
      final localInstant = DateTime.parse('2026-10-02T21:30:00.000Z');
      final sale = SaleModel.fromJson(_saleJson(localInstant.toIso8601String()));

      expect(sale.createdAt.isUtc, isFalse);
      expect(sale.createdAt.day, localInstant.toLocal().day);
      expect(sale.createdAt.month, localInstant.toLocal().month);
      expect(sale.createdAt.year, localInstant.toLocal().year);
    });
  });
}
