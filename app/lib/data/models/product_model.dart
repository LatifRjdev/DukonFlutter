import 'package:dukonpro/domain/entities/product.dart';

class ProductModel {
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

  const ProductModel({
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
  });

  // --- JSON (API) ---

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      supplierId: json['supplierId'] as String?,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      description: json['description'] as String?,
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      sellPrice: (json['sellPrice'] as num).toDouble(),
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),
      quantity: json['quantity'] as int? ?? 0,
      minQuantity: json['minQuantity'] as int? ?? 0,
      unit: json['unit'] as String? ?? 'PCS',
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'supplierId': supplierId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'costPrice': costPrice,
      'sellPrice': sellPrice,
      'wholesalePrice': wholesalePrice,
      'quantity': quantity,
      'minQuantity': minQuantity,
      'unit': unit,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- SQLite Map ---

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      supplierId: map['supplier_id'] as String?,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      description: map['description'] as String?,
      costPrice: (map['cost_price'] as num?)?.toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
      quantity: map['quantity'] as int? ?? 0,
      minQuantity: map['min_quantity'] as int? ?? 0,
      unit: map['unit'] as String? ?? 'PCS',
      imageUrl: map['image_url'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'category_id': categoryId,
      'category_name': categoryName,
      'supplier_id': supplierId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'wholesale_price': wholesalePrice,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'unit': unit,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // --- Domain Entity conversion ---

  factory ProductModel.fromEntity(Product entity) {
    return ProductModel(
      id: entity.id,
      storeId: entity.storeId,
      categoryId: entity.categoryId,
      categoryName: entity.categoryName,
      supplierId: entity.supplierId,
      name: entity.name,
      sku: entity.sku,
      barcode: entity.barcode,
      description: entity.description,
      costPrice: entity.costPrice,
      sellPrice: entity.sellPrice,
      wholesalePrice: entity.wholesalePrice,
      quantity: entity.quantity,
      minQuantity: entity.minQuantity,
      unit: entity.unit,
      imageUrl: entity.imageUrl,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      storeId: storeId,
      categoryId: categoryId,
      categoryName: categoryName,
      supplierId: supplierId,
      name: name,
      sku: sku,
      barcode: barcode,
      description: description,
      costPrice: costPrice,
      sellPrice: sellPrice,
      wholesalePrice: wholesalePrice,
      quantity: quantity,
      minQuantity: minQuantity,
      unit: unit,
      imageUrl: imageUrl,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
