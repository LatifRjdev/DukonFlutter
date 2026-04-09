import 'package:dokonpro/domain/entities/user.dart';

class UserModel {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final String? avatar;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    this.avatar,
    this.isActive = true,
    required this.createdAt,
  });

  // --- JSON (API) ---

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'avatar': avatar,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- SQLite Map ---

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      phone: map['phone'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      avatar: map['avatar'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'avatar': avatar,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // --- Domain Entity conversion ---

  factory UserModel.fromEntity(User entity) {
    return UserModel(
      id: entity.id,
      phone: entity.phone,
      name: entity.name,
      email: entity.email,
      avatar: entity.avatar,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  User toEntity() {
    return User(
      id: id,
      phone: phone,
      name: name,
      email: email,
      avatar: avatar,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
