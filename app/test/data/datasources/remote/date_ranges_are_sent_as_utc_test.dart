import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/dashboard_remote_datasource.dart';
import 'package:dukonpro/data/datasources/remote/finance_remote_datasource.dart';
import 'package:dukonpro/data/datasources/remote/loyalty_remote_datasource.dart';
import 'package:dukonpro/data/datasources/remote/sale_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;

  setUp(() {
    dio = _MockDioClient();
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          // `data` keeps the sales-history parser happy; the finance and
          // dashboard mappers ignore the extra key.
          data: <String, dynamic>{'data': <dynamic>[], 'total': 0},
        ));
  });

  Map<String, dynamic> sentParams() =>
      verify(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .last as Map<String, dynamic>;

  // A naive ISO string is parsed by Node as SERVER-local time, so a UTC-hosted
  // API would read a +05 device's range five hours off. Marking the instant
  // removes the dependency on where the API happens to run.
  //
  // The local DateTime here is deliberately built with DateTime() rather than
  // a literal instant, so the expectation is derived the same way in any zone.
  final from = DateTime(2026, 10, 2, 0, 0, 0);
  final to = DateTime(2026, 10, 2, 12, 0, 0);

  void expectUtcRange(String startKey, String endKey) {
    final params = sentParams();
    expect(params[startKey], endsWith('Z'),
        reason: '$startKey must identify an instant, not a wall-clock');
    expect(params[endKey], endsWith('Z'));
    expect(DateTime.parse(params[startKey] as String).toLocal(), from,
        reason: 'the instant must survive the conversion unchanged');
    expect(DateTime.parse(params[endKey] as String).toLocal(), to);
  }

  test('should send the dashboard range as an instant when a custom period is '
      'requested', () async {
    await DashboardRemoteDatasourceImpl(dioClient: dio)
        .getOverview('store-1', startDate: from, endDate: to);

    expectUtcRange('startDate', 'endDate');
  });

  test('should send the finance range as an instant when a custom period is '
      'requested', () async {
    await FinanceRemoteDatasourceImpl(dioClient: dio)
        .getDashboard('store-1', startDate: from, endDate: to);

    expectUtcRange('startDate', 'endDate');
  });

  test('should send the sales-history range as an instant when a custom period '
      'is requested', () async {
    await SaleRemoteDatasourceImpl(dioClient: dio)
        .getSales('store-1', dateFrom: from, dateTo: to);

    expectUtcRange('dateFrom', 'dateTo');
  });

  // The counterpart: a CALENDAR date must not be converted. .toUtc() on a
  // local midnight lands on the previous day, so a well-meaning sweep that
  // "fixed" this site would silently shift every loyalty range back a day.
  test('should send the loyalty range as a calendar date, not an instant',
      () async {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response<dynamic>(
              requestOptions: RequestOptions(path: ''),
              statusCode: 200,
              data: <String, dynamic>{},
            ));

    // The response mapper needs a fully populated body; this test is about
    // what went OUT, and the request has already been made by the time the
    // mapper runs.
    try {
      await LoyaltyRemoteDatasourceImpl(dioClient: dio)
          .getAnalytics('store-1', DateTime(2026, 10, 2), DateTime(2026, 10, 2));
    } catch (_) {}

    final params = sentParams();
    expect(params['from'], '2026-10-02');
    expect(params['to'], '2026-10-02');
  });
}
