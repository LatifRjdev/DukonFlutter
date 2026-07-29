import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/sale_repository.dart';
import 'checkout_event.dart';
import 'checkout_state.dart';

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  final SaleRepository _saleRepository;

  CheckoutBloc({required SaleRepository saleRepository})
      : _saleRepository = saleRepository,
        super(const CheckoutState()) {
    on<CheckoutInitiated>(_onInitiated);
    on<CheckoutPaymentMethodSelected>(_onPaymentMethodSelected);
    on<CheckoutCustomerSelected>(_onCustomerSelected);
    on<CheckoutDebtDetailsChanged>(_onDebtDetailsChanged);
    on<CheckoutDiscountApplied>(_onDiscountApplied);
    on<CheckoutPaidAmountChanged>(_onPaidAmountChanged);
    on<CheckoutProcessPayment>(_onProcessPayment);
  }

  void _onInitiated(CheckoutInitiated event, Emitter<CheckoutState> emit) {
    emit(CheckoutState(
      items: event.items,
      subtotal: event.subtotal,
      discount: event.discount,
      total: event.total,
      paidAmount: event.total,
      customerId: event.customerId,
      customerName: event.customerName,
      redemptionPoints: event.redemptionPoints,
    ));
  }

  void _onPaymentMethodSelected(
      CheckoutPaymentMethodSelected event, Emitter<CheckoutState> emit) {
    emit(state.copyWith(paymentMethod: event.paymentMethod, error: null));
  }

  void _onCustomerSelected(
      CheckoutCustomerSelected event, Emitter<CheckoutState> emit) {
    emit(state.copyWith(
      customerId: event.customerId,
      customerName: event.customerName,
      error: null,
    ));
  }

  void _onDebtDetailsChanged(
      CheckoutDebtDetailsChanged event, Emitter<CheckoutState> emit) {
    emit(state.copyWith(
      dueDate: event.dueDate,
      notes: event.notes,
      error: null,
    ));
  }

  void _onDiscountApplied(CheckoutDiscountApplied event, Emitter<CheckoutState> emit) {
    double discountAmount;
    if (event.discountType == 'PERCENTAGE') {
      discountAmount = state.subtotal * event.discount / 100;
    } else {
      discountAmount = event.discount;
    }
    final newTotal = state.subtotal - discountAmount;
    emit(state.copyWith(
      discount: event.discount,
      discountType: event.discountType,
      total: newTotal > 0 ? newTotal : 0,
      paidAmount: newTotal > 0 ? newTotal : 0,
      error: null,
    ));
  }

  void _onPaidAmountChanged(CheckoutPaidAmountChanged event, Emitter<CheckoutState> emit) {
    emit(state.copyWith(paidAmount: event.paidAmount, error: null));
  }

  Future<void> _onProcessPayment(
      CheckoutProcessPayment event, Emitter<CheckoutState> emit) async {
    emit(state.copyWith(isProcessing: true, error: null));
    try {
      final localId = const Uuid().v4();
      final occurredAt = DateTime.now().toUtc().toIso8601String();
      final change =
          state.paidAmount > state.total ? state.paidAmount - state.total : 0.0;
      final debt =
          state.total > state.paidAmount ? state.total - state.paidAmount : 0.0;

      final saleData = <String, dynamic>{
        'items': state.items
            .map((item) => {
                  'productId': item.productId,
                  'quantity': item.quantity,
                  if (item.discount > 0) 'discount': item.discount,
                })
            .toList(),
        if (state.discount > 0) 'discount': state.discount,
        if (state.discount > 0) 'discountType': state.discountType,
        'paymentType': state.paymentMethod,
        'paidAmount': state.paidAmount,
        if (state.customerId != null) 'customerId': state.customerId,
        if (state.redemptionPoints > 0) 'redemptionPoints': state.redemptionPoints,
        if (state.dueDate != null) 'dueDate': state.dueDate!.toUtc().toIso8601String(),
        if (state.notes != null && state.notes!.isNotEmpty) 'notes': state.notes,
        // localId + occurredAt are accepted by the API and also used by the
        // offline-replay path so the receipt the cashier holds matches the
        // row that eventually lands on the server.
        'localId': localId,
        'occurredAt': occurredAt,
        // Offline-only metadata. SaleRemoteDatasource strips these before
        // POSTing because the API rejects unknown fields. SaleRepository
        // reads them when constructing the local-only Sale entity so the
        // success screen shows the right total instead of 0 TJS.
        '_offlineSubtotal': state.subtotal,
        '_offlineTotal': state.total,
        '_offlineChange': change,
        '_offlineDebt': debt,
      };

      final sale = await _saleRepository.createSale(event.storeId, saleData);
      emit(state.copyWith(isProcessing: false, saleResult: sale));
    } catch (e) {
      emit(state.copyWith(isProcessing: false, error: mapErrorToUserMessage(e)));
    }
  }
}
