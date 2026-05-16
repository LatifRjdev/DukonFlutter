import '../../domain/entities/zakat_calculation.dart';
import '../../domain/entities/zakat_settings.dart';
import '../../domain/entities/zakat_payment.dart';
import '../../domain/repositories/zakat_repository.dart';
import '../datasources/remote/zakat_remote_datasource.dart';

class ZakatRepositoryImpl implements ZakatRepository {
  final ZakatRemoteDatasource _remoteDatasource;

  ZakatRepositoryImpl({required ZakatRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<ZakatCalculation> calculate(String storeId) {
    return _remoteDatasource.calculate(storeId);
  }

  @override
  Future<ZakatSettings?> getSettings(String storeId) {
    return _remoteDatasource.getSettings(storeId);
  }

  @override
  Future<ZakatSettings> upsertSettings(String storeId, Map<String, dynamic> data) {
    return _remoteDatasource.upsertSettings(storeId, data);
  }

  @override
  Future<ZakatPaymentsPage> getPayments(
    String storeId, {
    int page = 1,
    int limit = 20,
  }) {
    return _remoteDatasource.getPayments(storeId, page: page, limit: limit);
  }

  @override
  Future<ZakatPayment> createPayment(String storeId, Map<String, dynamic> data) {
    return _remoteDatasource.createPayment(storeId, data);
  }
}
