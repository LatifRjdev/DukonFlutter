import 'dart:convert';

import 'package:dokonpro/domain/entities/store.dart';

class StoreModel {
  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String currency;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final Map<String, dynamic> settings;
  final bool isActive;
  final DateTime createdAt;

  const StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    this.currency = 'TJS',
    this.address,
    this.phone,
    this.logoUrl,
    this.settings = const {},
    this.isActive = true,
    required this.createdAt,
  });

  // --- JSON (API) ---

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      currency: json['currency'] as String? ?? 'TJS',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      logoUrl: json['logoUrl'] as String?,
      settings: json['settings'] is Map<String, dynamic>
          ? json['settings'] as Map<String, dynamic>
          : const {},
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'category': category,
      'currency': currency,
      'address': address,
      'phone': phone,
      'logoUrl': logoUrl,
      'settings': settings,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- SQLite Map ---

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      currency: map['currency'] as String? ?? 'TJS',
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      logoUrl: map['logo_url'] as String?,
      settings: map['settings'] != null
          ? jsonDecode(map['settings'] as String) as Map<String, dynamic>
          : const {},
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'category': category,
      'currency': currency,
      'address': address,
      'phone': phone,
      'logo_url': logoUrl,
      'settings': jsonEncode(settings),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // --- Domain Entity conversion ---

  factory StoreModel.fromEntity(Store entity) {
    return StoreModel(
      id: entity.id,
      ownerId: entity.ownerId,
      name: entity.name,
      category: entity.category,
      currency: entity.currency,
      address: entity.address,
      phone: entity.phone,
      logoUrl: entity.logoUrl,
      settings: entity.settings,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  Store toEntity() {
    return Store(
      id: id,
      ownerId: ownerId,
      name: name,
      category: category,
      currency: currency,
      address: address,
      phone: phone,
      logoUrl: logoUrl,
      settings: settings,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
