import 'package:equatable/equatable.dart';

abstract class ZakatEvent extends Equatable {
  const ZakatEvent();
  @override
  List<Object?> get props => [];
}

class ZakatCalculateRequested extends ZakatEvent {
  final String storeId;
  const ZakatCalculateRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class ZakatSettingsRequested extends ZakatEvent {
  final String storeId;
  const ZakatSettingsRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class ZakatSettingsUpdated extends ZakatEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const ZakatSettingsUpdated({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class ZakatPaymentSubmitted extends ZakatEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const ZakatPaymentSubmitted({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

// Spec E B.1: paginate zakat history. `page` defaults to 1 to keep
// existing call sites compatible; the load-more UI bumps it.
class ZakatPaymentsRequested extends ZakatEvent {
  final String storeId;
  final int page;
  final int limit;
  const ZakatPaymentsRequested({
    required this.storeId,
    this.page = 1,
    this.limit = 20,
  });
  @override
  List<Object?> get props => [storeId, page, limit];
}
