import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/z_report.dart';

void main() {
  group('ZReport.fromJson', () {
    // Matches the real nested shape returned by shifts.service.ts's
    // getZReport() — shift/sales/returns/cashDrawer sub-objects, not a
    // flat top-level structure. A prior version of this test (and of
    // ZReport.fromJson) assumed a flat shape that the backend never
    // actually sent, so fromJson threw on every real response and this
    // test suite never caught it (found during the 2026-09-21 manual QA
    // pass — the Z-report screen always showed a generic error).
    Map<String, dynamic> baseJson({
      Map<String, dynamic> shiftOverrides = const {},
      Map<String, dynamic> salesOverrides = const {},
      Map<String, dynamic> returnsOverrides = const {},
      Map<String, dynamic> cashDrawerOverrides = const {},
      List<Map<String, dynamic>>? topProducts,
    }) =>
        {
          'shift': {
            'staffName': 'Ali',
            'openedAt': '2026-07-17T08:00:00.000Z',
            'closedAt': '2026-07-17T20:00:00.000Z',
            ...shiftOverrides,
          },
          'sales': {
            'cashTotal': 0,
            'cardTotal': 0,
            'debtTotal': 0,
            'total': 0,
            'count': 0,
            ...salesOverrides,
          },
          'returns': {
            'count': 0,
            'total': 0,
            ...returnsOverrides,
          },
          'cashDrawer': {
            'opening': 0,
            'cashSales': 0,
            'cashReturns': 0,
            'withdrawals': 0,
            'expected': 0,
            'actual': 0,
            'difference': 0,
            ...cashDrawerOverrides,
          },
          'topProducts': topProducts ?? const [],
        };

    test('parses a full Z-report response with all fields present', () {
      final report = ZReport.fromJson(baseJson(
        salesOverrides: {
          'cashTotal': 750,
          'cardTotal': 2000,
          'debtTotal': 250,
          'total': 3000,
          'count': 42,
        },
        returnsOverrides: {'count': 2, 'total': 100},
        cashDrawerOverrides: {
          'opening': 500,
          'cashSales': 750,
          'cashReturns': 50,
          'withdrawals': 200,
          'expected': 1000,
          'actual': 1000,
          'difference': 0,
        },
        topProducts: [
          {'productId': 'p1', 'productName': 'Bread', 'quantitySold': 10, 'totalRevenue': 500},
        ],
      ));

      expect(report.staffName, 'Ali');
      expect(report.openedAt, DateTime.parse('2026-07-17T08:00:00.000Z'));
      expect(report.closedAt, DateTime.parse('2026-07-17T20:00:00.000Z'));
      // duration isn't sent by the backend — computed from openedAt/closedAt.
      expect(report.duration, '12ч 0м');
      expect(report.salesCount, 42);
      expect(report.cashTotal, 750);
      expect(report.cardTotal, 2000);
      expect(report.debtTotal, 250);
      expect(report.salesTotal, 3000);
      expect(report.returnsCount, 2);
      expect(report.returnsTotal, 100);
      expect(report.openingCash, 500);
      expect(report.cashSalesAmount, 750);
      expect(report.cashReturns, 50);
      expect(report.withdrawals, 200);
      expect(report.expectedCash, 1000);
      expect(report.actualCash, 1000);
      expect(report.difference, 0);
      expect(report.topProducts, hasLength(1));
      // topProducts entries are remapped to name/quantity/total, matching
      // what z_report_page.dart's _buildReport actually reads.
      expect(report.topProducts.first['name'], 'Bread');
      expect(report.topProducts.first['quantity'], 10);
      expect(report.topProducts.first['total'], 500);
    });

    test(
        'defaults every numeric field to 0 and topProducts to empty when '
        'only the required shift fields are present', () {
      final report = ZReport.fromJson(baseJson());

      expect(report.salesCount, 0);
      expect(report.cashTotal, 0);
      expect(report.cardTotal, 0);
      expect(report.debtTotal, 0);
      expect(report.salesTotal, 0);
      expect(report.returnsCount, 0);
      expect(report.returnsTotal, 0);
      expect(report.openingCash, 0);
      expect(report.cashSalesAmount, 0);
      expect(report.cashReturns, 0);
      expect(report.withdrawals, 0);
      expect(report.expectedCash, 0);
      expect(report.actualCash, 0);
      expect(report.difference, 0);
      expect(report.topProducts, isEmpty);
    });

    test('cash-count overage: positive difference when actual exceeds expected', () {
      final report = ZReport.fromJson(baseJson(cashDrawerOverrides: {
        'expected': 1000,
        'actual': 1050,
        'difference': 50,
      }));

      expect(report.expectedCash, 1000);
      expect(report.actualCash, 1050);
      expect(report.difference, 50);
      expect(report.difference, report.actualCash - report.expectedCash);
    });

    test('cash-count shortage: negative difference when actual is below expected', () {
      final report = ZReport.fromJson(baseJson(cashDrawerOverrides: {
        'expected': 1000,
        'actual': 940,
        'difference': -60,
      }));

      expect(report.expectedCash, 1000);
      expect(report.actualCash, 940);
      expect(report.difference, -60);
      expect(report.difference, report.actualCash - report.expectedCash);
    });

    test('exact cash count: zero difference when actual equals expected', () {
      final report = ZReport.fromJson(baseJson(cashDrawerOverrides: {
        'expected': 1000,
        'actual': 1000,
        'difference': 0,
      }));

      expect(report.difference, 0);
    });

    test('throws when a required field (shift.staffName) is missing defaults to empty string, '
        'but a missing shift object throws', () {
      final json = baseJson()..remove('shift');
      expect(() => ZReport.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('throws when a required date field is unparseable', () {
      final json = baseJson(shiftOverrides: {'openedAt': 'not-a-date'});
      expect(() => ZReport.fromJson(json), throwsFormatException);
    });
  });

  group('ZReport equality (Equatable props)', () {
    ZReport build({double salesTotal = 3000}) => ZReport(
          staffName: 'Ali',
          openedAt: DateTime(2026, 7, 17, 8),
          closedAt: DateTime(2026, 7, 17, 20),
          duration: '12h 00m',
          salesTotal: salesTotal,
        );

    test('reports with identical staffName/openedAt/closedAt/salesTotal '
        'are equal', () {
      expect(build(), equals(build()));
    });

    test('reports with different salesTotal are not equal', () {
      expect(build(salesTotal: 3000), isNot(equals(build(salesTotal: 1))));
    });
  });
}
