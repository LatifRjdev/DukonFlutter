import 'package:equatable/equatable.dart';

class ZakatCalculation extends Equatable {
  final double stockValue;
  final double receivables;
  final double payables;
  final double netAssets;
  final double nisabAmount;
  final double zakatDue;
  final bool isAboveNisab;

  const ZakatCalculation({
    required this.stockValue,
    required this.receivables,
    required this.payables,
    required this.netAssets,
    required this.nisabAmount,
    required this.zakatDue,
    required this.isAboveNisab,
  });

  @override
  List<Object?> get props => [stockValue, netAssets, zakatDue, isAboveNisab];
}
