import 'package:dokonpro/domain/entities/stock_movement.dart';

class StockMovementModel {
  final String id;
  final String productId;
  final String type;
  final int quantity;
  final double? unitCost;
  final double? totalCost;
  final String? supplierId;
  final String? reference;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.unitCost,
    this.totalCost,
    this.supplierId,
    this.reference,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  // --- JSON (API) ---

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      id: json['id'] as String,
      productId: json['productId'] as String,
      type: json['type'] as String,
      quantity: json['quantity'] as int,
      unitCost: (json['unitCost'] as num?)?.toDouble(),
      totalCost: (json['totalCost'] as num?)?.toDouble(),
      supplierId: json['supplierId'] as String?,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'type': type,
      'quantity': quantity,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'supplierId': supplierId,
      'reference': reference,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- SQLite Map ---

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      type: map['type'] as String,
      quantity: map['quantity'] as int,
      unitCost: (map['unit_cost'] as num?)?.toDouble(),
      totalCost: (map['total_cost'] as num?)?.toDouble(),
      supplierId: map['supplier_id'] as String?,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'supplier_id': supplierId,
      'reference': reference,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // --- Domain Entity conversion ---

  factory StockMovementModel.fromEntity(StockMovement entity) {
    return StockMovementModel(
      id: entity.id,
      productId: entity.productId,
      type: entity.type,
      quantity: entity.quantity,
      unitCost: entity.unitCost,
      totalCost: entity.totalCost,
      supplierId: entity.supplierId,
      reference: entity.reference,
      notes: entity.notes,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
    );
  }

  StockMovement toEntity() {
    return StockMovement(
      id: id,
      productId: productId,
      type: type,
      quantity: quantity,
      unitCost: unitCost,
      totalCost: totalCost,
      supplierId: supplierId,
      reference: reference,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
