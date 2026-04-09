import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double? costPrice;
  final double discount;
  final double total;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.costPrice,
    this.discount = 0,
    required this.total,
  });

  @override
  List<Object?> get props => [id, saleId, productId, quantity, total];
}
