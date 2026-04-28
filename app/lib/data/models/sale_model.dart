import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/data/models/sale_item_model.dart';

class SaleModel {
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
  final List<SaleItemModel> items;
  final DateTime createdAt;

  const SaleModel({
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
  });

  // --- JSON (API) ---

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      staffId: json['staffId'] as String?,
      shiftId: json['shiftId'] as String?,
      receiptNo: json['receiptNo'] as String,
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountType: json['discountType'] as String?,
      total: (json['total'] as num).toDouble(),
      paymentType: json['paymentType'] as String,
      paidAmount: (json['paidAmount'] as num).toDouble(),
      change: (json['change'] as num?)?.toDouble() ?? 0,
      debtAmount: (json['debtAmount'] as num?)?.toDouble() ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      status: json['status'] as String? ?? 'COMPLETED',
      notes: json['notes'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'customerId': customerId,
      'customerName': customerName,
      'staffId': staffId,
      'shiftId': shiftId,
      'receiptNo': receiptNo,
      'subtotal': subtotal,
      'discount': discount,
      'discountType': discountType,
      'total': total,
      'paymentType': paymentType,
      'paidAmount': paidAmount,
      'change': change,
      'debtAmount': debtAmount,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- SQLite Map ---
  // Note: items are stored in a separate sale_items table,
  // so they are not included in toMap/fromMap.

  factory SaleModel.fromMap(Map<String, dynamic> map,
      {List<SaleItemModel> items = const []}) {
    return SaleModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      staffId: map['staff_id'] as String?,
      shiftId: map['shift_id'] as String?,
      receiptNo: map['receipt_no'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      discountType: map['discount_type'] as String?,
      total: (map['total'] as num).toDouble(),
      paymentType: map['payment_type'] as String,
      paidAmount: (map['paid_amount'] as num).toDouble(),
      change: (map['change_amount'] as num?)?.toDouble() ?? 0,
      debtAmount: (map['debt_amount'] as num?)?.toDouble() ?? 0,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      status: map['status'] as String? ?? 'COMPLETED',
      notes: map['notes'] as String?,
      items: items,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'customer_id': customerId,
      'customer_name': customerName,
      'staff_id': staffId,
      'shift_id': shiftId,
      'receipt_no': receiptNo,
      'subtotal': subtotal,
      'discount': discount,
      'discount_type': discountType,
      'total': total,
      'payment_type': paymentType,
      'paid_amount': paidAmount,
      'change_amount': change,
      'debt_amount': debtAmount,
      'due_date': dueDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // --- Domain Entity conversion ---

  factory SaleModel.fromEntity(Sale entity) {
    return SaleModel(
      id: entity.id,
      storeId: entity.storeId,
      customerId: entity.customerId,
      customerName: entity.customerName,
      staffId: entity.staffId,
      shiftId: entity.shiftId,
      receiptNo: entity.receiptNo,
      subtotal: entity.subtotal,
      discount: entity.discount,
      discountType: entity.discountType,
      total: entity.total,
      paymentType: entity.paymentType,
      paidAmount: entity.paidAmount,
      change: entity.change,
      debtAmount: entity.debtAmount,
      dueDate: entity.dueDate,
      status: entity.status,
      notes: entity.notes,
      items: entity.items
          .map((e) => SaleItemModel.fromEntity(e))
          .toList(),
      createdAt: entity.createdAt,
    );
  }

  Sale toEntity() {
    return Sale(
      id: id,
      storeId: storeId,
      customerId: customerId,
      customerName: customerName,
      staffId: staffId,
      shiftId: shiftId,
      receiptNo: receiptNo,
      subtotal: subtotal,
      discount: discount,
      discountType: discountType,
      total: total,
      paymentType: paymentType,
      paidAmount: paidAmount,
      change: change,
      debtAmount: debtAmount,
      dueDate: dueDate,
      status: status,
      notes: notes,
      items: items.map((e) => e.toEntity()).toList(),
      createdAt: createdAt,
    );
  }
}
