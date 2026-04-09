import 'package:equatable/equatable.dart';

abstract class StoreEvent extends Equatable {
  const StoreEvent();
  @override
  List<Object?> get props => [];
}

class StoreLoadRequested extends StoreEvent {}

class StoreCreateRequested extends StoreEvent {
  final String name;
  final String category;
  final String currency;
  final String? address;
  final String? phone;
  const StoreCreateRequested({
    required this.name,
    required this.category,
    this.currency = 'TJS',
    this.address,
    this.phone,
  });
  @override
  List<Object?> get props => [name, category, currency];
}

class StoreSelected extends StoreEvent {
  final String storeId;
  const StoreSelected(this.storeId);
  @override
  List<Object?> get props => [storeId];
}

class StoreResetRequested extends StoreEvent {}
