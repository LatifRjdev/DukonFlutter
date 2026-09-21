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

  // Backend's GET /shifts/:id/z-report nests fields under shift/sales/
  // returns/cashDrawer, with different names than this entity's flat
  // properties (e.g. cashDrawer.opening -> openingCash, cashDrawer.actual
  // -> actualCash, sales.total -> salesTotal, topProducts[].productName ->
  // topProducts[].name) — see shifts.service.ts's getZReport(). The mobile
  // side was written against a flat shape that never matched, so this
  // parse threw on every real response and the Z-report screen always
  // showed a generic error instead of the report (found during the
  // 2026-09-21 manual QA pass). `duration` isn't sent by the backend at
  // all — computed here from openedAt/closedAt instead.
  factory ZReport.fromJson(Map<String, dynamic> json) {
    final shift = json['shift'] as Map<String, dynamic>? ?? const {};
    final sales = json['sales'] as Map<String, dynamic>? ?? const {};
    final returns = json['returns'] as Map<String, dynamic>? ?? const {};
    final cashDrawer = json['cashDrawer'] as Map<String, dynamic>? ?? const {};

    final openedAt = DateTime.parse(shift['openedAt'] as String);
    final closedAt = DateTime.parse(shift['closedAt'] as String);
    final diff = closedAt.difference(openedAt);

    return ZReport(
      staffName: shift['staffName'] as String? ?? '',
      openedAt: openedAt,
      closedAt: closedAt,
      duration: '${diff.inHours}ч ${diff.inMinutes % 60}м',
      salesCount: sales['count'] as int? ?? 0,
      cashTotal: (sales['cashTotal'] as num?)?.toDouble() ?? 0,
      cardTotal: (sales['cardTotal'] as num?)?.toDouble() ?? 0,
      debtTotal: (sales['debtTotal'] as num?)?.toDouble() ?? 0,
      salesTotal: (sales['total'] as num?)?.toDouble() ?? 0,
      returnsCount: returns['count'] as int? ?? 0,
      returnsTotal: (returns['total'] as num?)?.toDouble() ?? 0,
      openingCash: (cashDrawer['opening'] as num?)?.toDouble() ?? 0,
      cashSalesAmount: (cashDrawer['cashSales'] as num?)?.toDouble() ?? 0,
      cashReturns: (cashDrawer['cashReturns'] as num?)?.toDouble() ?? 0,
      withdrawals: (cashDrawer['withdrawals'] as num?)?.toDouble() ?? 0,
      expectedCash: (cashDrawer['expected'] as num?)?.toDouble() ?? 0,
      actualCash: (cashDrawer['actual'] as num?)?.toDouble() ?? 0,
      difference: (cashDrawer['difference'] as num?)?.toDouble() ?? 0,
      topProducts: (json['topProducts'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .map((p) => {
                    'name': p['productName'],
                    'quantity': p['quantitySold'],
                    'total': p['totalRevenue'],
                  })
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [staffName, openedAt, closedAt, salesTotal];
}
