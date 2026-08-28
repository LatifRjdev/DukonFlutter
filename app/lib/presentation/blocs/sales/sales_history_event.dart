import 'package:equatable/equatable.dart';

abstract class SalesHistoryEvent extends Equatable {
  const SalesHistoryEvent();
  @override
  List<Object?> get props => [];
}

class SalesHistoryLoadRequested extends SalesHistoryEvent {
  final String storeId;
  final int page;
  const SalesHistoryLoadRequested({required this.storeId, this.page = 1});
  @override
  List<Object?> get props => [storeId, page];
}

class SalesHistoryFilterByDate extends SalesHistoryEvent {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  const SalesHistoryFilterByDate({this.dateFrom, this.dateTo});
  @override
  List<Object?> get props => [dateFrom, dateTo];
}

class SalesHistoryFilterByPaymentMethod extends SalesHistoryEvent {
  final String? paymentType;
  const SalesHistoryFilterByPaymentMethod(this.paymentType);
  @override
  List<Object?> get props => [paymentType];
}

class SalesHistoryFilterByStatus extends SalesHistoryEvent {
  final String? status;
  const SalesHistoryFilterByStatus(this.status);
  @override
  List<Object?> get props => [status];
}

class SalesHistoryLoadMore extends SalesHistoryEvent {}

class SalesHistoryRefundSale extends SalesHistoryEvent {
  final String storeId;
  final String saleId;
  final Map<String, dynamic> refundData;
  const SalesHistoryRefundSale({
    required this.storeId,
    required this.saleId,
    required this.refundData,
  });
  @override
  List<Object?> get props => [storeId, saleId, refundData];
}
