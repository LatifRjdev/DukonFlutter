import 'package:dokonpro/domain/entities/customer.dart';

class CustomerModel {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final DateTime? birthday;
  final String? notes;
  final int loyaltyPoints;
  final double totalSpent;
  final double debt;
  final bool isActive;

  const CustomerModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.birthday,
    this.notes,
    this.loyaltyPoints = 0,
    this.totalSpent = 0,
    this.debt = 0,
    this.isActive = true,
  });

  // --- JSON (API) ---

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      notes: json['notes'] as String?,
      loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'phone': phone,
      'email': email,
      'birthday': birthday?.toIso8601String(),
      'notes': notes,
      'loyaltyPoints': loyaltyPoints,
      'totalSpent': totalSpent,
      'debt': debt,
      'isActive': isActive,
    };
  }

  // --- SQLite Map ---

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      birthday: map['birthday'] != null
          ? DateTime.parse(map['birthday'] as String)
          : null,
      notes: map['notes'] as String?,
      loyaltyPoints: map['loyalty_points'] as int? ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
      debt: (map['debt'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'phone': phone,
      'email': email,
      'birthday': birthday?.toIso8601String(),
      'notes': notes,
      'loyalty_points': loyaltyPoints,
      'total_spent': totalSpent,
      'debt': debt,
      'is_active': isActive ? 1 : 0,
    };
  }

  // --- Domain Entity conversion ---

  factory CustomerModel.fromEntity(Customer entity) {
    return CustomerModel(
      id: entity.id,
      storeId: entity.storeId,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      birthday: entity.birthday,
      notes: entity.notes,
      loyaltyPoints: entity.loyaltyPoints,
      totalSpent: entity.totalSpent,
      debt: entity.debt,
      isActive: entity.isActive,
    );
  }

  Customer toEntity() {
    return Customer(
      id: id,
      storeId: storeId,
      name: name,
      phone: phone,
      email: email,
      birthday: birthday,
      notes: notes,
      loyaltyPoints: loyaltyPoints,
      totalSpent: totalSpent,
      debt: debt,
      isActive: isActive,
    );
  }
}
