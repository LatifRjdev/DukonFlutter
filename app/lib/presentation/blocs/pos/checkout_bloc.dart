import 'package:flutter_bloc/flutter_bloc.dart';
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
    ));
  }

  void _onPaymentMethodSelected(
      CheckoutPaymentMethodSelected event, Emitter<CheckoutState> emit) {
    emit(state.copyWith(paymentMethod: event.paymentMethod, error: null));
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
      };

      final sale = await _saleRepository.createSale(event.storeId, saleData);
      emit(state.copyWith(isProcessing: false, saleResult: sale));
    } catch (e) {
      emit(state.copyWith(isProcessing: false, error: mapErrorToUserMessage(e)));
    }
  }
}
