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

// Spec E B.1: payments-loaded state carries pagination metadata so
// the page can render a "load more" button when more rows exist on
// the server. `hasMore` is derived from currentPage < totalPages so
// the page can't accidentally fetch a non-existent page.
class ZakatPaymentsLoaded extends ZakatState {
  final List<ZakatPayment> payments;
  final int total;
  final int totalPages;
  final int currentPage;
  const ZakatPaymentsLoaded(
    this.payments, {
    this.total = 0,
    this.totalPages = 1,
    this.currentPage = 1,
  });

  bool get hasMore => currentPage < totalPages;

  @override
  List<Object?> get props => [payments, total, totalPages, currentPage];
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
