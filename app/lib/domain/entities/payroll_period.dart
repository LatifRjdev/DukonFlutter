import 'package:equatable/equatable.dart';

import 'payroll_entry.dart';

class PayrollPeriod extends Equatable {
  final String id;
  final int month;
  final int year;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final int staffCount;
  final List<PayrollEntry> payrolls;

  const PayrollPeriod({
    required this.id,
    required this.month,
    required this.year,
    required this.status,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.staffCount = 0,
    this.payrolls = const [],
  });

  factory PayrollPeriod.fromJson(Map<String, dynamic> json) {
    return PayrollPeriod(
      id: json['id'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      status: json['status'] as String,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      staffCount: json['staffCount'] as int? ?? 0,
      payrolls: (json['payrolls'] as List?)
              ?.map((e) => PayrollEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id, month, year, status, totalAmount];
}
