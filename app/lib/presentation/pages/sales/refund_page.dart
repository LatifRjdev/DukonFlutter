import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/sale.dart';
import '../../blocs/sales/sales_history_bloc.dart';
import '../../blocs/sales/sales_history_event.dart';
import '../../blocs/sales/sales_history_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';

class RefundPage extends StatefulWidget {
  final Sale sale;

  const RefundPage({super.key, required this.sale});

  @override
  State<RefundPage> createState() => _RefundPageState();
}

class _RefundPageState extends State<RefundPage> {
  final _reasonController = TextEditingController();
  final Set<int> _selectedItems = {};

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  double get _refundTotal {
    double total = 0;
    for (final index in _selectedItems) {
      total += widget.sale.items[index].total;
    }
    return total;
  }

  void _toggleItem(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
      } else {
        _selectedItems.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedItems.length == widget.sale.items.length) {
        _selectedItems.clear();
      } else {
        _selectedItems
            .addAll(List.generate(widget.sale.items.length, (i) => i));
      }
    });
  }

  void _confirmRefund() {
    if (_selectedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердить возврат?'),
        content: Text(
          'Сумма возврата: ${Formatters.price(_refundTotal)}\n'
          'Выбрано позиций: ${_selectedItems.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processRefund();
            },
            child: const Text('Подтвердить',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _processRefund() {
    final storeState = context.read<StoreBloc>().state;
    final storeId = storeState is StoreLoaded
        ? storeState.selectedStore?.id ?? ''
        : '';

    final selectedItemIds = _selectedItems
        .map((index) => widget.sale.items[index].id)
        .toList();

    final refundData = <String, dynamic>{
      'itemIds': selectedItemIds,
      'reason': _reasonController.text.trim(),
    };

    context.read<SalesHistoryBloc>().add(
          SalesHistoryRefundSale(
            storeId: storeId,
            saleId: widget.sale.id,
            refundData: refundData,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesHistoryBloc, SalesHistoryState>(
      listener: (context, state) {
        if (state is SalesHistoryLoaded && !state.isRefunding) {
          final updatedSale = state.sales
              .where((s) => s.id == widget.sale.id)
              .toList();
          if (updatedSale.isNotEmpty &&
              updatedSale.first.status != widget.sale.status) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Возврат успешно оформлен'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Возврат'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instructions
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusMd),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline,
                                color: AppColors.warning, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Выберите товары для возврата',
                                style: TextStyle(
                                    color: AppColors.lightTextPrimary,
                                    fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Receipt info
                      Text(
                        'Чек ${widget.sale.receiptNo}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Select all
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Товары',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: _selectAll,
                            child: Text(
                              _selectedItems.length ==
                                      widget.sale.items.length
                                  ? 'Снять все'
                                  : 'Выбрать все',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Items list
                      ...List.generate(widget.sale.items.length,
                          (index) {
                        final item = widget.sale.items[index];
                        final isSelected =
                            _selectedItems.contains(index);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => _toggleItem(index),
                            color: isSelected
                                ? AppColors.error
                                    .withValues(alpha: 0.04)
                                : null,
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) =>
                                      _toggleItem(index),
                                  activeColor: AppColors.error,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.quantity} x ${Formatters.price(item.unitPrice)}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.lightTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Formatters.price(item.total),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Reason
                      const Text('Причина возврата',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _reasonController,
                        hint: 'Укажите причину возврата',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom bar with total and confirm
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  boxShadow: AppShadows.sm,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Сумма возврата:',
                            style: TextStyle(
                                fontSize: 16,
                                color: AppColors.lightTextSecondary)),
                        Text(
                          Formatters.price(_refundTotal),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<SalesHistoryBloc,
                        SalesHistoryState>(
                      builder: (context, state) {
                        final isRefunding = state
                                is SalesHistoryLoaded &&
                            state.isRefunding;
                        return AppButton(
                          text: 'Оформить возврат',
                          type: AppButtonType.danger,
                          icon: Icons.undo,
                          onPressed: _selectedItems.isNotEmpty
                              ? _confirmRefund
                              : null,
                          isLoading: isRefunding,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
