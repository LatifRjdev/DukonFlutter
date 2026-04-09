import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_state.dart';
import '../../blocs/pos/checkout_bloc.dart';
import '../../blocs/pos/checkout_event.dart';
import '../../blocs/pos/checkout_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';

class CreditSalePage extends StatefulWidget {
  const CreditSalePage({super.key});

  @override
  State<CreditSalePage> createState() => _CreditSalePageState();
}

class _CreditSalePageState extends State<CreditSalePage> {
  final _notesController = TextEditingController();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  void _selectCustomer() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите клиента',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Center(
              child: Text('Список клиентов пуст',
                  style: TextStyle(color: AppColors.lightTextSecondary)),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Создать нового клиента',
              icon: Icons.person_add_outlined,
              type: AppButtonType.outlined,
              onPressed: () {
                Navigator.pop(ctx);
                _showCreateCustomerDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCreateCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый клиент'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              label: 'Имя',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: phoneController,
              label: 'Телефон',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _selectedCustomerId = 'new';
                  _selectedCustomerName = nameController.text.trim();
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _confirm(double total) {
    if (_selectedCustomerId == null) return;

    final storeState = context.read<StoreBloc>().state;
    final storeId = storeState is StoreLoaded
        ? storeState.selectedStore?.id ?? ''
        : '';

    context.read<CheckoutBloc>()
      ..add(CheckoutPaymentMethodSelected('DEBT'))
      ..add(CheckoutPaidAmountChanged(0))
      ..add(CheckoutProcessPayment(storeId: storeId));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutBloc, CheckoutState>(
      listener: (context, state) {
        if (state.saleResult != null) {
          context.go('/pos/success', extra: {
            'sale': state.saleResult,
          });
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Продажа в долг'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocBuilder<CartBloc, CartState>(
          builder: (context, cart) {
            final total = cart.total;
            final isProcessing = context.watch<CheckoutBloc>().state.isProcessing;

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppConstants.spacingLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppCard(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            child: Column(
                              children: [
                                const Text('Сумма долга',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.lightTextSecondary)),
                                const SizedBox(height: 8),
                                Text(
                                  '${total.toStringAsFixed(2)} сом.',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('Клиент *',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AppCard(
                            onTap: _selectCustomer,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd),
                                  ),
                                  child: Icon(
                                    _selectedCustomerId != null
                                        ? Icons.person
                                        : Icons.person_add_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedCustomerName ?? 'Выберите клиента',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: _selectedCustomerId != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: _selectedCustomerId != null
                                          ? AppColors.lightTextPrimary
                                          : AppColors.lightTextHint,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppColors.lightTextSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Срок оплаты',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AppCard(
                            onTap: _selectDueDate,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDate(_dueDate),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                const Icon(Icons.edit_outlined,
                                    size: 20, color: AppColors.lightTextSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Примечание',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _notesController,
                            hint: 'Добавьте примечание (необязательно)',
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingLg),
                    child: AppButton(
                      text: isProcessing ? 'Обработка...' : 'Оформить в долг',
                      icon: Icons.check,
                      onPressed: !isProcessing && _selectedCustomerId != null
                          ? () => _confirm(total)
                          : null,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
