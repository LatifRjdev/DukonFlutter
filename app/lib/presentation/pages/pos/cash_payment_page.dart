import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../blocs/pos/checkout_bloc.dart';
import '../../blocs/pos/checkout_event.dart';
import '../../blocs/pos/checkout_state.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class CashPaymentPage extends StatefulWidget {
  const CashPaymentPage({super.key});

  @override
  State<CashPaymentPage> createState() => _CashPaymentPageState();
}

class _CashPaymentPageState extends State<CashPaymentPage> {
  final _receivedController = TextEditingController();
  double _receivedAmount = 0;

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  void _onReceivedChanged(String value) {
    setState(() {
      _receivedAmount = double.tryParse(value) ?? 0;
    });
  }

  void _confirm(double total) {
    if (_receivedAmount < total) return;

    final storeState = context.read<StoreBloc>().state;
    final storeId = storeState is StoreLoaded
        ? storeState.selectedStore?.id ?? ''
        : '';

    context.read<CheckoutBloc>()
      ..add(CheckoutPaidAmountChanged(_receivedAmount))
      ..add(CheckoutProcessPayment(storeId: storeId));
  }

  void _quickAmount(double amount) {
    _receivedController.text = amount.toStringAsFixed(0);
    _onReceivedChanged(_receivedController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutBloc, CheckoutState>(
      listener: (context, state) {
        if (state.saleResult != null) {
          context.go('/pos/success', extra: {'sale': state.saleResult});
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.surface,
        body: SafeArea(
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, cart) {
              final total = cart.total;
              final change = _receivedAmount - total;
              final isProcessing = context.watch<CheckoutBloc>().state.isProcessing;

              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.pop(),
                        ),
                        const Text('Оплата наличными',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Amount to pay card (teal light bg)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: context.infoBg,
                              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                            ),
                            child: Column(
                              children: [
                                Text('Сумма к оплате',
                                  style: TextStyle(fontSize: 14, color: context.textSecondary),),
                                const SizedBox(height: 8),
                                Text(_formatPrice(total),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Received amount input
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Получено от клиента',
                              style: TextStyle(fontSize: 14, color: context.textSecondary)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _receivedController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                            ],
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: const TextStyle(fontSize: 24, color: AppColors.disabled),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                borderSide: BorderSide(color: context.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onChanged: _onReceivedChanged,
                          ),
                          const SizedBox(height: 16),

                          // Quick amount chips
                          Row(
                            children: [
                              _quickChip(500),
                              const SizedBox(width: 8),
                              _quickChip(1000),
                              const SizedBox(width: 8),
                              _quickChip(2000),
                              const SizedBox(width: 8),
                              _quickChip(5000),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _quickAmount(total),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: context.border),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Center(
                                      child: Text('Без сдачи',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Change card
                          if (_receivedAmount > 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: change >= 0
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                              ),
                              child: Column(
                                children: [
                                  Text(change >= 0 ? 'Сдача' : 'Недостаточно',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: change >= 0 ? AppColors.success : AppColors.error,
                                    )),
                                  const SizedBox(height: 8),
                                  Text(_formatPrice(change.abs()),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: change >= 0 ? AppColors.success : AppColors.error,
                                    )),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: !isProcessing && _receivedAmount >= total
                            ? () => _confirm(total)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.disabled.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                        ),
                        child: Text(
                          isProcessing ? 'Обработка...' : 'Завершить и печатать чек',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _quickChip(double amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _quickAmount(amount),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: context.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(amount.toStringAsFixed(0),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}
