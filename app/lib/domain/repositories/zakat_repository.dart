import '../entities/zakat_calculation.dart';
import '../entities/zakat_settings.dart';
import '../entities/zakat_payment.dart';

abstract class ZakatRepository {
  Future<ZakatCalculation> calculate(String storeId);
  Future<ZakatSettings?> getSettings(String storeId);
  Future<ZakatSettings> upsertSettings(String storeId, Map<String, dynamic> data);
  Future<List<ZakatPayment>> getPayments(String storeId);
  Future<ZakatPayment> createPayment(String storeId, Map<String, dynamic> data);
}
