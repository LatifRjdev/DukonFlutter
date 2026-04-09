import 'package:equatable/equatable.dart';

class ShiftModel extends Equatable {
  final String id;
  final String storeId;
  final String staffId;
  final String? staffName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? difference;
  final double salesTotal;
  final int salesCount;
  final double cashSales;
  final double cardSales;
  final double debtSales;
  final double returnsTotal;
  final int returnsCount;
  final String status;
  final String? notes;

  const ShiftModel({
    required this.id,
    required this.storeId,
    required this.staffId,
    this.staffName,
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.difference,
    this.salesTotal = 0,
    this.salesCount = 0,
    this.cashSales = 0,
    this.cardSales = 0,
    this.debtSales = 0,
    this.returnsTotal = 0,
    this.returnsCount = 0,
    required this.status,
    this.notes,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      staffId: json['staffId'] as String,
      staffName: json['staffName'] as String?,
      openedAt: DateTime.parse(json['openedAt'] as String),
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
      openingCash: (json['openingCash'] as num).toDouble(),
      closingCash: (json['closingCash'] as num?)?.toDouble(),
      expectedCash: (json['expectedCash'] as num?)?.toDouble(),
      difference: (json['difference'] as num?)?.toDouble(),
      salesTotal: (json['salesTotal'] as num?)?.toDouble() ?? 0,
      salesCount: json['salesCount'] as int? ?? 0,
      cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0,
      cardSales: (json['cardSales'] as num?)?.toDouble() ?? 0,
      debtSales: (json['debtSales'] as num?)?.toDouble() ?? 0,
      returnsTotal: (json['returnsTotal'] as num?)?.toDouble() ?? 0,
      returnsCount: json['returnsCount'] as int? ?? 0,
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, storeId, staffId, status];
}
