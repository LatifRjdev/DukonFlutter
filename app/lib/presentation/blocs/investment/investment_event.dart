import 'package:equatable/equatable.dart';

abstract class InvestmentEvent extends Equatable {
  const InvestmentEvent();
  @override
  List<Object?> get props => [];
}

class InvestmentListRequested extends InvestmentEvent {
  final String storeId;
  final int page;
  final String? status;
  const InvestmentListRequested({required this.storeId, this.page = 1, this.status});
  @override
  List<Object?> get props => [storeId, page, status];
}

class InvestmentSummaryRequested extends InvestmentEvent {
  final String storeId;
  const InvestmentSummaryRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class InvestmentCreateRequested extends InvestmentEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const InvestmentCreateRequested({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class InvestmentUpdateRequested extends InvestmentEvent {
  final String storeId;
  final String id;
  final Map<String, dynamic> data;
  const InvestmentUpdateRequested({required this.storeId, required this.id, required this.data});
  @override
  List<Object?> get props => [storeId, id, data];
}

class InvestmentDeleteRequested extends InvestmentEvent {
  final String storeId;
  final String id;
  const InvestmentDeleteRequested({required this.storeId, required this.id});
  @override
  List<Object?> get props => [storeId, id];
}
