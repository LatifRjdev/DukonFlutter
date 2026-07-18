import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/z_report.dart';

void main() {
  group('ZReport.fromJson', () {
    Map<String, dynamic> baseJson({Map<String, dynamic> overrides = const {}}) => {
          'staffName': 'Ali',
          'openedAt': '2026-07-17T08:00:00.000Z',
          'closedAt': '2026-07-17T20:00:00.000Z',
          'duration': '12h 00m',
          ...overrides,
        };

    test('parses a full Z-report response with all fields present', () {
      final report = ZReport.fromJson({
        'staffName': 'Ali',
        'openedAt': '2026-07-17T08:00:00.000Z',
        'closedAt': '2026-07-17T20:00:00.000Z',
        'duration': '12h 00m',
        'salesCount': 42,
        'cashTotal': 750,
        'cardTotal': 2000,
        'debtTotal': 250,
        'salesTotal': 3000,
        'returnsCount': 2,
        'returnsTotal': 100,
        'openingCash': 500,
        'cashSalesAmount': 750,
        'cashReturns': 50,
        'withdrawals': 200,
        'expectedCash': 1000,
        'actualCash': 1000,
        'difference': 0,
        'topProducts': [
          {'productId': 'p1', 'name': 'Bread', 'quantity': 10},
        ],
      });

      expect(report.staffName, 'Ali');
      expect(report.openedAt, DateTime.parse('2026-07-17T08:00:00.000Z'));
      expect(report.closedAt, DateTime.parse('2026-07-17T20:00:00.000Z'));
      expect(report.duration, '12h 00m');
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
      expect(report.topProducts.first['productId'], 'p1');
    });

    test(
        'defaults every numeric field to 0 and topProducts to empty when '
        'only the required fields are present', () {
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

    test('cash-count overage: positive difference when actualCash exceeds '
        'expectedCash', () {
      final report = ZReport.fromJson(baseJson(overrides: {
        'expectedCash': 1000,
        'actualCash': 1050,
        'difference': 50,
      }));

      expect(report.expectedCash, 1000);
      expect(report.actualCash, 1050);
      expect(report.difference, 50);
      expect(report.difference, report.actualCash - report.expectedCash);
    });

    test('cash-count shortage: negative difference when actualCash is '
        'below expectedCash', () {
      final report = ZReport.fromJson(baseJson(overrides: {
        'expectedCash': 1000,
        'actualCash': 940,
        'difference': -60,
      }));

      expect(report.expectedCash, 1000);
      expect(report.actualCash, 940);
      expect(report.difference, -60);
      expect(report.difference, report.actualCash - report.expectedCash);
    });

    test('exact cash count: zero difference when actualCash equals '
        'expectedCash', () {
      final report = ZReport.fromJson(baseJson(overrides: {
        'expectedCash': 1000,
        'actualCash': 1000,
        'difference': 0,
      }));

      expect(report.difference, 0);
    });

    test('throws when a required field (staffName) is missing', () {
      final json = baseJson()..remove('staffName');
      expect(() => ZReport.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('throws when a required date field is unparseable', () {
      final json = baseJson(overrides: {'openedAt': 'not-a-date'});
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
