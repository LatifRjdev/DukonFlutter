import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final String? avatar;
  final bool isActive;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    this.avatar,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, phone, name, email, avatar, isActive, createdAt];
}
