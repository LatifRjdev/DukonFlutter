import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String storeId;
  final String? categoryId;
  final String? categoryName;
  final String? supplierId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final double? costPrice;
  final double sellPrice;
  final double? wholesalePrice;
  final int quantity;
  final int minQuantity;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final double? paybackPercent;

  const Product({
    required this.id,
    required this.storeId,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.costPrice,
    required this.sellPrice,
    this.wholesalePrice,
    this.quantity = 0,
    this.minQuantity = 0,
    this.unit = 'PCS',
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.paybackPercent,
  });

  bool get isLowStock => quantity > 0 && quantity <= minQuantity;
  bool get isOutOfStock => quantity <= 0;
  double? get profit => costPrice != null ? sellPrice - costPrice! : null;
  double? get margin => costPrice != null && costPrice! > 0
      ? ((sellPrice - costPrice!) / sellPrice) * 100
      : null;

  @override
  List<Object?> get props =>
      [id, storeId, name, sku, barcode, sellPrice, quantity, isActive, paybackPercent];
}
