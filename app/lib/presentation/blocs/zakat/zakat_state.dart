import 'package:equatable/equatable.dart';
import '../../../domain/entities/zakat_calculation.dart';
import '../../../domain/entities/zakat_settings.dart';
import '../../../domain/entities/zakat_payment.dart';

abstract class ZakatState extends Equatable {
  const ZakatState();
  @override
  List<Object?> get props => [];
}

class ZakatInitial extends ZakatState {}
class ZakatLoading extends ZakatState {}

class ZakatCalculated extends ZakatState {
  final ZakatCalculation calculation;
  final ZakatSettings? settings;
  const ZakatCalculated({required this.calculation, this.settings});
  @override
  List<Object?> get props => [calculation, settings];
}

class ZakatSettingsLoaded extends ZakatState {
  final ZakatSettings settings;
  const ZakatSettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

class ZakatPaymentsLoaded extends ZakatState {
  final List<ZakatPayment> payments;
  const ZakatPaymentsLoaded(this.payments);
  @override
  List<Object?> get props => [payments];
}

class ZakatActionSuccess extends ZakatState {
  final String message;
  const ZakatActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ZakatError extends ZakatState {
  final String message;
  const ZakatError(this.message);
  @override
  List<Object?> get props => [message];
}
