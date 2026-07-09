import 'package:equatable/equatable.dart';
import 'sale_item.dart';

class Sale extends Equatable {
  final String id;
  final String storeId;
  final String? customerId;
  final String? customerName;
  final String? staffId;
  final String? shiftId;
  final String receiptNo;
  final double subtotal;
  final double discount;
  final String? discountType;
  final double total;
  final String paymentType;
  final double paidAmount;
  final double change;
  final double debtAmount;
  final DateTime? dueDate;
  final String status;
  final String? notes;
  final List<SaleItem> items;
  final DateTime createdAt;
  final int pointsEarned;
  final int pointsBalance;

  const Sale({
    required this.id,
    required this.storeId,
    this.customerId,
    this.customerName,
    this.staffId,
    this.shiftId,
    required this.receiptNo,
    required this.subtotal,
    this.discount = 0,
    this.discountType,
    required this.total,
    required this.paymentType,
    required this.paidAmount,
    this.change = 0,
    this.debtAmount = 0,
    this.dueDate,
    this.status = 'COMPLETED',
    this.notes,
    this.items = const [],
    required this.createdAt,
    this.pointsEarned = 0,
    this.pointsBalance = 0,
  });

  @override
  List<Object?> get props => [id, storeId, receiptNo, total, status, createdAt];
}
