import 'package:equatable/equatable.dart';

class StockMovement extends Equatable {
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

  const StockMovement({
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

  @override
  List<Object?> get props => [id, productId, type, quantity, createdAt];
}
