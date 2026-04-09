import 'package:equatable/equatable.dart';

abstract class ProductFormEvent extends Equatable {
  const ProductFormEvent();
  @override
  List<Object?> get props => [];
}

class ProductFormUpdateStep extends ProductFormEvent {
  final int step;
  const ProductFormUpdateStep(this.step);
  @override
  List<Object?> get props => [step];
}

class ProductFormSaveStep extends ProductFormEvent {
  final int step;
  final Map<String, dynamic> data;
  const ProductFormSaveStep({required this.step, required this.data});
  @override
  List<Object?> get props => [step, data];
}

class ProductFormSubmit extends ProductFormEvent {
  final String storeId;
  const ProductFormSubmit({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class ProductFormLoadProduct extends ProductFormEvent {
  final String storeId;
  final String productId;
  const ProductFormLoadProduct({required this.storeId, required this.productId});
  @override
  List<Object?> get props => [storeId, productId];
}

class ProductFormReset extends ProductFormEvent {}
