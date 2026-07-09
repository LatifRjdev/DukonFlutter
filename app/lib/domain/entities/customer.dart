import 'package:equatable/equatable.dart';

class Customer extends Equatable {
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
  final String? telegramChatId;

  const Customer({
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
    this.telegramChatId,
  });

  @override
  List<Object?> get props => [id, storeId, name, phone, debt];
}
