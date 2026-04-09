import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/sale_repository.dart';
import 'sales_history_event.dart';
import 'sales_history_state.dart';

class SalesHistoryBloc extends Bloc<SalesHistoryEvent, SalesHistoryState> {
  final SaleRepository _saleRepository;
  String _storeId = '';

  SalesHistoryBloc({required SaleRepository saleRepository})
      : _saleRepository = saleRepository,
        super(SalesHistoryInitial()) {
    on<SalesHistoryLoadRequested>(_onLoadRequested);
    on<SalesHistoryFilterByDate>(_onFilterByDate);
    on<SalesHistoryFilterByPaymentMethod>(_onFilterByPaymentMethod);
    on<SalesHistoryLoadMore>(_onLoadMore);
    on<SalesHistoryRefundSale>(_onRefundSale);
  }

  Future<void> _onLoadRequested(
      SalesHistoryLoadRequested event, Emitter<SalesHistoryState> emit) async {
    _storeId = event.storeId;
    emit(SalesHistoryLoading());
    try {
      final currentState = state;
      DateTime? dateFrom;
      DateTime? dateTo;
      String? paymentType;

      if (currentState is SalesHistoryLoaded) {
        dateFrom = currentState.dateFrom;
        dateTo = currentState.dateTo;
        paymentType = currentState.paymentType;
      }

      final result = await _saleRepository.getSales(
        event.storeId,
        page: event.page,
        dateFrom: dateFrom,
        dateTo: dateTo,
        paymentType: paymentType,
      );
      emit(SalesHistoryLoaded(
        sales: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        dateFrom: dateFrom,
        dateTo: dateTo,
        paymentType: paymentType,
      ));
    } catch (e) {
      emit(SalesHistoryError(e.toString()));
    }
  }

  Future<void> _onFilterByDate(
      SalesHistoryFilterByDate event, Emitter<SalesHistoryState> emit) async {
    final currentState = state;
    if (currentState is SalesHistoryLoaded) {
      emit(currentState.copyWith(
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        clearDateFrom: event.dateFrom == null,
        clearDateTo: event.dateTo == null,
      ));
    }
    add(SalesHistoryLoadRequested(storeId: _storeId));
  }

  Future<void> _onFilterByPaymentMethod(
      SalesHistoryFilterByPaymentMethod event, Emitter<SalesHistoryState> emit) async {
    final currentState = state;
    if (currentState is SalesHistoryLoaded) {
      emit(currentState.copyWith(
        paymentType: event.paymentType,
        clearPaymentType: event.paymentType == null,
      ));
    }
    add(SalesHistoryLoadRequested(storeId: _storeId));
  }

  Future<void> _onLoadMore(
      SalesHistoryLoadMore event, Emitter<SalesHistoryState> emit) async {
    final currentState = state;
    if (currentState is SalesHistoryLoaded && currentState.hasMore && !currentState.isLoadingMore) {
      emit(currentState.copyWith(isLoadingMore: true));
      try {
        final nextPage = currentState.currentPage + 1;
        final result = await _saleRepository.getSales(
          _storeId,
          page: nextPage,
          dateFrom: currentState.dateFrom,
          dateTo: currentState.dateTo,
          paymentType: currentState.paymentType,
        );
        emit(SalesHistoryLoaded(
          sales: [...currentState.sales, ...result.data],
          total: result.total,
          totalPages: result.totalPages,
          currentPage: nextPage,
          dateFrom: currentState.dateFrom,
          dateTo: currentState.dateTo,
          paymentType: currentState.paymentType,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> _onRefundSale(
      SalesHistoryRefundSale event, Emitter<SalesHistoryState> emit) async {
    final currentState = state;
    if (currentState is SalesHistoryLoaded) {
      emit(currentState.copyWith(isRefunding: true));
      try {
        final refundedSale = await _saleRepository.refundSale(
          event.storeId,
          event.saleId,
          event.refundData,
        );
        final updatedSales = currentState.sales.map((sale) {
          return sale.id == event.saleId ? refundedSale : sale;
        }).toList();
        emit(currentState.copyWith(sales: updatedSales, isRefunding: false));
      } catch (e) {
        emit(currentState.copyWith(isRefunding: false));
      }
    }
  }
}
