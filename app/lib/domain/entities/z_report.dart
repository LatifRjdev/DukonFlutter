import 'package:equatable/equatable.dart';

class ZReport extends Equatable {
  final String staffName;
  final DateTime openedAt;
  final DateTime closedAt;
  final String duration;
  final int salesCount;
  final double cashTotal;
  final double cardTotal;
  final double debtTotal;
  final double salesTotal;
  final int returnsCount;
  final double returnsTotal;
  final double openingCash;
  final double cashSalesAmount;
  final double cashReturns;
  final double withdrawals;
  final double expectedCash;
  final double actualCash;
  final double difference;
  final List<Map<String, dynamic>> topProducts;

  const ZReport({
    required this.staffName,
    required this.openedAt,
    required this.closedAt,
    required this.duration,
    this.salesCount = 0,
    this.cashTotal = 0,
    this.cardTotal = 0,
    this.debtTotal = 0,
    this.salesTotal = 0,
    this.returnsCount = 0,
    this.returnsTotal = 0,
    this.openingCash = 0,
    this.cashSalesAmount = 0,
    this.cashReturns = 0,
    this.withdrawals = 0,
    this.expectedCash = 0,
    this.actualCash = 0,
    this.difference = 0,
    this.topProducts = const [],
  });

  factory ZReport.fromJson(Map<String, dynamic> json) {
    return ZReport(
      staffName: json['staffName'] as String,
      openedAt: DateTime.parse(json['openedAt'] as String),
      closedAt: DateTime.parse(json['closedAt'] as String),
      duration: json['duration'] as String,
      salesCount: json['salesCount'] as int? ?? 0,
      cashTotal: (json['cashTotal'] as num?)?.toDouble() ?? 0,
      cardTotal: (json['cardTotal'] as num?)?.toDouble() ?? 0,
      debtTotal: (json['debtTotal'] as num?)?.toDouble() ?? 0,
      salesTotal: (json['salesTotal'] as num?)?.toDouble() ?? 0,
      returnsCount: json['returnsCount'] as int? ?? 0,
      returnsTotal: (json['returnsTotal'] as num?)?.toDouble() ?? 0,
      openingCash: (json['openingCash'] as num?)?.toDouble() ?? 0,
      cashSalesAmount: (json['cashSalesAmount'] as num?)?.toDouble() ?? 0,
      cashReturns: (json['cashReturns'] as num?)?.toDouble() ?? 0,
      withdrawals: (json['withdrawals'] as num?)?.toDouble() ?? 0,
      expectedCash: (json['expectedCash'] as num?)?.toDouble() ?? 0,
      actualCash: (json['actualCash'] as num?)?.toDouble() ?? 0,
      difference: (json['difference'] as num?)?.toDouble() ?? 0,
      topProducts: (json['topProducts'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [staffName, openedAt, closedAt, salesTotal];
}
