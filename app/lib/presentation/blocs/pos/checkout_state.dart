import 'package:equatable/equatable.dart';
import '../../../domain/entities/sale.dart';
import 'cart_state.dart';

class CheckoutState extends Equatable {
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final String discountType;
  final double total;
  final String paymentMethod;
  final double paidAmount;
  final String? customerId;
  final String? customerName;
  final int redemptionPoints;
  final DateTime? dueDate;
  final String? notes;
  final bool isProcessing;
  final Sale? saleResult;
  final String? error;

  const CheckoutState({
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.discountType = 'FIXED',
    this.total = 0,
    this.paymentMethod = 'CASH',
    this.paidAmount = 0,
    this.customerId,
    this.customerName,
    this.redemptionPoints = 0,
    this.dueDate,
    this.notes,
    this.isProcessing = false,
    this.saleResult,
    this.error,
  });

  double get change => paidAmount > total ? paidAmount - total : 0;
  bool get isCompleted => saleResult != null;

  CheckoutState copyWith({
    List<CartItem>? items,
    double? subtotal,
    double? discount,
    String? discountType,
    double? total,
    String? paymentMethod,
    double? paidAmount,
    String? customerId,
    String? customerName,
    int? redemptionPoints,
    DateTime? dueDate,
    String? notes,
    bool? isProcessing,
    Sale? saleResult,
    String? error,
  }) {
    return CheckoutState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAmount: paidAmount ?? this.paidAmount,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      redemptionPoints: redemptionPoints ?? this.redemptionPoints,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      isProcessing: isProcessing ?? this.isProcessing,
      saleResult: saleResult,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        items,
        subtotal,
        discount,
        discountType,
        total,
        paymentMethod,
        paidAmount,
        customerId,
        redemptionPoints,
        dueDate,
        notes,
        isProcessing,
        saleResult,
        error,
      ];
}
