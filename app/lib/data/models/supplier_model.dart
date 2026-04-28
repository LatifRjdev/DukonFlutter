import 'package:dukonpro/domain/entities/supplier.dart';

class SupplierModel {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double debt;

  const SupplierModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.debt = 0,
  });

  // --- JSON (API) ---

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'debt': debt,
    };
  }

  // --- SQLite Map ---

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      debt: (map['debt'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'debt': debt,
    };
  }

  // --- Domain Entity conversion ---

  factory SupplierModel.fromEntity(Supplier entity) {
    return SupplierModel(
      id: entity.id,
      storeId: entity.storeId,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      address: entity.address,
      notes: entity.notes,
      debt: entity.debt,
    );
  }

  Supplier toEntity() {
    return Supplier(
      id: id,
      storeId: storeId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      debt: debt,
    );
  }
}
