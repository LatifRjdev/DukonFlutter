import 'package:equatable/equatable.dart';

class Store extends Equatable {
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

  const Store({
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

  @override
  List<Object?> get props => [id, ownerId, name, category, currency, address, phone, logoUrl, isActive];
}
