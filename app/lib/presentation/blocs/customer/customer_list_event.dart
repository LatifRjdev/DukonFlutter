import 'package:equatable/equatable.dart';

abstract class CustomerListEvent extends Equatable {
  const CustomerListEvent();
  @override
  List<Object?> get props => [];
}

class CustomerListLoadRequested extends CustomerListEvent {
  final String storeId;
  final int page;
  final String? search;
  const CustomerListLoadRequested({required this.storeId, this.page = 1, this.search});
  @override
  List<Object?> get props => [storeId, page, search];
}

class CustomerListSearchChanged extends CustomerListEvent {
  final String query;
  const CustomerListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class CustomerCreateRequested extends CustomerListEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const CustomerCreateRequested({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class CustomerUpdateRequested extends CustomerListEvent {
  final String storeId;
  final String customerId;
  final Map<String, dynamic> data;
  const CustomerUpdateRequested({
    required this.storeId,
    required this.customerId,
    required this.data,
  });
  @override
  List<Object?> get props => [storeId, customerId, data];
}
