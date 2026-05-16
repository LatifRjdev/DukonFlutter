import '../entities/zakat_calculation.dart';
import '../entities/zakat_settings.dart';
import '../entities/zakat_payment.dart';

// Spec E B.1: paginated page of zakat history rows. Lives in the
// domain layer so the repository contract stays framework-free and
// the data layer / bloc both depend on the same shape.
typedef ZakatPaymentsPage = ({
  List<ZakatPayment> data,
  int total,
  int totalPages,
  int currentPage,
});

abstract class ZakatRepository {
  Future<ZakatCalculation> calculate(String storeId);
  Future<ZakatSettings?> getSettings(String storeId);
  Future<ZakatSettings> upsertSettings(String storeId, Map<String, dynamic> data);
  Future<ZakatPaymentsPage> getPayments(
    String storeId, {
    int page = 1,
    int limit = 20,
  });
  Future<ZakatPayment> createPayment(String storeId, Map<String, dynamic> data);
}
