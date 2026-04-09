import 'package:equatable/equatable.dart';
import '../../../domain/entities/store.dart';

abstract class StoreState extends Equatable {
  const StoreState();
  @override
  List<Object?> get props => [];
}

class StoreInitial extends StoreState {}
class StoreLoading extends StoreState {}

class StoreLoaded extends StoreState {
  final List<Store> stores;
  final Store? selectedStore;
  const StoreLoaded({required this.stores, this.selectedStore});
  @override
  List<Object?> get props => [stores, selectedStore];
}

class StoreError extends StoreState {
  final String message;
  const StoreError(this.message);
  @override
  List<Object?> get props => [message];
}
