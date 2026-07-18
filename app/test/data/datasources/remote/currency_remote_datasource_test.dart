import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/currency_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late CurrencyRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = CurrencyRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  group('CurrencyRemoteDatasourceImpl.getLatestRates', () {
    test('maps known currency codes to their flag and label', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'rates': {
            'USD': 10.5,
            'RUB': 0.12,
            'EUR': 11.3,
            'CNY': 1.5,
          },
        }),
      );

      final rates = await ds.getLatestRates();

      expect(rates.length, 4);
      final usd = rates.firstWhere((r) => r.code == 'USD');
      expect(usd.rate, 10.5);
      expect(usd.flag, '🇺🇸');
      expect(usd.label, 'Доллар США');

      final rub = rates.firstWhere((r) => r.code == 'RUB');
      expect(rub.flag, '🇷🇺');
      expect(rub.label, 'Российский рубль');

      final eur = rates.firstWhere((r) => r.code == 'EUR');
      expect(eur.flag, '🇪🇺');
      expect(eur.label, 'Евро');

      final cny = rates.firstWhere((r) => r.code == 'CNY');
      expect(cny.flag, '🇨🇳');
      expect(cny.label, 'Китайский юань');
    });

    test('falls back to empty flag and raw code label for unknown currency',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'rates': {'GBP': 13.7},
        }),
      );

      final rates = await ds.getLatestRates();

      expect(rates.length, 1);
      expect(rates.first.code, 'GBP');
      expect(rates.first.rate, 13.7);
      expect(rates.first.flag, '');
      expect(rates.first.label, 'GBP');
    });

    test('returns empty list when rates map is empty', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp({'rates': <String, dynamic>{}}));

      final rates = await ds.getLatestRates();

      expect(rates, isEmpty);
    });

    test('converts integer rate values to double', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'rates': {'USD': 10},
        }),
      );

      final rates = await ds.getLatestRates();

      expect(rates.first.rate, 10.0);
      expect(rates.first.rate, isA<double>());
    });

    test('requests the latest-rates endpoint', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp({'rates': <String, dynamic>{}}));

      await ds.getLatestRates();

      verify(() => dio.get<dynamic>('/currencies/latest-rates')).called(1);
    });
  });

  group('CurrencyRemoteDatasourceImpl.getRateHistory', () {
    test('parses history entries with dates and rates', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'history': [
              {'date': '2026-05-01T00:00:00.000Z', 'rate': 10.1},
              {'date': '2026-05-02T00:00:00.000Z', 'rate': 10.2},
            ],
          }));

      final result = await ds.getRateHistory('USD');

      expect(result.code, 'USD');
      expect(result.history.length, 2);
      expect(result.history[0].date, DateTime.parse('2026-05-01T00:00:00.000Z'));
      expect(result.history[0].rate, 10.1);
      expect(result.history[1].rate, 10.2);
    });

    test('returns empty history list when history array is empty', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'history': []}));

      final result = await ds.getRateHistory('EUR');

      expect(result.code, 'EUR');
      expect(result.history, isEmpty);
    });

    test('passes code as a query parameter', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'history': []}));

      await ds.getRateHistory('CNY');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['code'], 'CNY');
    });
  });
}
