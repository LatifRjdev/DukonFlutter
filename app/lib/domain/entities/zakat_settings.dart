import 'package:equatable/equatable.dart';

class ZakatSettings extends Equatable {
  final String id;
  final String storeId;
  final double nisabGold;
  final double nisabSilver;
  final String nisabCurrency;
  final double nisabAmount;
  final DateTime? haulStartDate;
  final double zakatRate;
  final bool includeStock;
  final bool includeCash;
  final bool includeDebts;

  const ZakatSettings({
    required this.id,
    required this.storeId,
    this.nisabGold = 85,
    this.nisabSilver = 595,
    this.nisabCurrency = 'TJS',
    this.nisabAmount = 0,
    this.haulStartDate,
    this.zakatRate = 2.5,
    this.includeStock = true,
    this.includeCash = true,
    this.includeDebts = true,
  });

  @override
  List<Object?> get props => [id, storeId, nisabAmount, zakatRate];
}
