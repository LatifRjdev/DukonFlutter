import 'package:equatable/equatable.dart';

import 'payroll_adjustment.dart';

class PayrollEntry extends Equatable {
  final String id;
  final String staffId;
  final String staffName;
  final String? staffRole;
  final String? staffAvatar;
  final double baseSalary;
  final double commission;
  final double? commissionRate;
  final double salesTotal;
  final int shiftsWorked;
  final int shiftsExpected;
  final double totalAmount;
  final bool isPaid;
  final DateTime? paidAt;
  final List<PayrollAdjustment> adjustments;

  const PayrollEntry({
    required this.id,
    required this.staffId,
    required this.staffName,
    this.staffRole,
    this.staffAvatar,
    this.baseSalary = 0,
    this.commission = 0,
    this.commissionRate,
    this.salesTotal = 0,
    this.shiftsWorked = 0,
    this.shiftsExpected = 0,
    this.totalAmount = 0,
    this.isPaid = false,
    this.paidAt,
    this.adjustments = const [],
  });

  factory PayrollEntry.fromJson(Map<String, dynamic> json) {
    return PayrollEntry(
      id: json['id'] as String,
      staffId: json['staffId'] as String,
      staffName: json['staffName'] as String,
      staffRole: json['staffRole'] as String?,
      staffAvatar: json['staffAvatar'] as String?,
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      commissionRate: (json['commissionRate'] as num?)?.toDouble(),
      salesTotal: (json['salesTotal'] as num?)?.toDouble() ?? 0,
      shiftsWorked: json['shiftsWorked'] as int? ?? 0,
      shiftsExpected: json['shiftsExpected'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      isPaid: json['isPaid'] as bool? ?? false,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      adjustments: (json['adjustments'] as List?)
              ?.map((e) => PayrollAdjustment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id, staffId, staffName, totalAmount, isPaid];
}
