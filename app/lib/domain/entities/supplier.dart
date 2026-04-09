import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double debt;

  const Supplier({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.debt = 0,
  });

  @override
  List<Object?> get props => [id, storeId, name, phone, debt];
}
