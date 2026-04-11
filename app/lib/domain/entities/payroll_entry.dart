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
    // The backend returns the raw Prisma Payroll shape, where staff identity
    // lives under `staff.user.*` rather than flat `staffName`/`staffRole`/
    // `staffAvatar` keys. Tolerate either shape so the list renders whatever
    // the server returns instead of hitting a 'Null is not a subtype of
    // String' cast when the flat keys are absent (FD-P0-003).
    final staff = json['staff'] as Map<String, dynamic>?;
    final staffUser = staff?['user'] as Map<String, dynamic>?;
    return PayrollEntry(
      id: json['id'] as String,
      staffId: (json['staffId'] as String?) ?? (staff?['id'] as String?) ?? '',
      staffName: (json['staffName'] as String?) ??
          (staffUser?['name'] as String?) ??
          '',
      staffRole:
          (json['staffRole'] as String?) ?? (staff?['role'] as String?),
      staffAvatar: (json['staffAvatar'] as String?) ??
          (staffUser?['avatar'] as String?),
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
