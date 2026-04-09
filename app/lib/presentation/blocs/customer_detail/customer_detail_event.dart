import 'package:equatable/equatable.dart';

abstract class CustomerDetailEvent extends Equatable {
  const CustomerDetailEvent();
  @override
  List<Object?> get props => [];
}

class CustomerDetailRequested extends CustomerDetailEvent {
  final String storeId;
  final String customerId;
  const CustomerDetailRequested({required this.storeId, required this.customerId});
  @override
  List<Object?> get props => [storeId, customerId];
}
