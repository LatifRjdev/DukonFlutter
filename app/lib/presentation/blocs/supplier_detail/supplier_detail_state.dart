import 'package:equatable/equatable.dart';
import '../../../core/errors/app_message.dart';
import '../../../domain/entities/supplier.dart';

abstract class SupplierDetailState extends Equatable {
  const SupplierDetailState();
  @override
  List<Object?> get props => [];
}

class SupplierDetailInitial extends SupplierDetailState {}
class SupplierDetailLoading extends SupplierDetailState {}

class SupplierDetailLoaded extends SupplierDetailState {
  final Supplier supplier;
  const SupplierDetailLoaded(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class SupplierDetailError extends SupplierDetailState {
  final AppMessage message;
  const SupplierDetailError(this.message);
  @override
  List<Object?> get props => [message];
}
