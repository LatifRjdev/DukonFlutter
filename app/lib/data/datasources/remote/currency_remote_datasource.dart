import '../../../core/network/dio_client.dart';

class CurrencyRate {
  final String code;
  final double rate;
  final String flag;
  final String label;
  const CurrencyRate({required this.code, required this.rate, required this.flag, required this.label});
}

class CurrencyRateHistory {
  final String code;
  final List<({DateTime date, double rate})> history;
  const CurrencyRateHistory({required this.code, required this.history});
}

abstract class CurrencyRemoteDatasource {
  Future<List<CurrencyRate>> getLatestRates();
  Future<CurrencyRateHistory> getRateHistory(String code);
}

class CurrencyRemoteDatasourceImpl implements CurrencyRemoteDatasource {
  final DioClient _dioClient;
  CurrencyRemoteDatasourceImpl({required DioClient dioClient}) : _dioClient = dioClient;

  static const _flags = {'USD': '🇺🇸', 'RUB': '🇷🇺', 'EUR': '🇪🇺', 'CNY': '🇨🇳'};
  static const _labels = {'USD': 'Доллар США', 'RUB': 'Российский рубль', 'EUR': 'Евро', 'CNY': 'Китайский юань'};

  @override
  Future<List<CurrencyRate>> getLatestRates() async {
    final response = await _dioClient.get('/currencies/latest-rates');
    final data = response.data as Map<String, dynamic>;
    final rates = data['rates'] as Map<String, dynamic>;
    return rates.entries.map((e) => CurrencyRate(
      code: e.key,
      rate: (e.value as num).toDouble(),
      flag: _flags[e.key] ?? '',
      label: _labels[e.key] ?? e.key,
    )).toList();
  }

  @override
  Future<CurrencyRateHistory> getRateHistory(String code) async {
    final response = await _dioClient.get('/currencies/rate-history', queryParameters: {'code': code});
    final data = response.data as Map<String, dynamic>;
    final history = (data['history'] as List).map((item) {
      final m = item as Map<String, dynamic>;
      return (date: DateTime.parse(m['date'] as String), rate: (m['rate'] as num).toDouble());
    }).toList();
    return CurrencyRateHistory(code: code, history: history);
  }
}
