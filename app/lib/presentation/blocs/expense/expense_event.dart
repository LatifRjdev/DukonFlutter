import 'package:equatable/equatable.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();
  @override
  List<Object?> get props => [];
}

class ExpenseListRequested extends ExpenseEvent {
  final String storeId;
  final int page;
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;
  const ExpenseListRequested({required this.storeId, this.page = 1, this.category, this.startDate, this.endDate});
  @override
  List<Object?> get props => [storeId, page, category, startDate, endDate];
}

class ExpenseCreateRequested extends ExpenseEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const ExpenseCreateRequested({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class ExpenseUpdateRequested extends ExpenseEvent {
  final String storeId;
  final String id;
  final Map<String, dynamic> data;
  const ExpenseUpdateRequested({required this.storeId, required this.id, required this.data});
  @override
  List<Object?> get props => [storeId, id, data];
}

class ExpenseDeleteRequested extends ExpenseEvent {
  final String storeId;
  final String id;
  const ExpenseDeleteRequested({required this.storeId, required this.id});
  @override
  List<Object?> get props => [storeId, id];
}
