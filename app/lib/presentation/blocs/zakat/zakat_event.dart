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

class ZakatPaymentsRequested extends ZakatEvent {
  final String storeId;
  const ZakatPaymentsRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}
