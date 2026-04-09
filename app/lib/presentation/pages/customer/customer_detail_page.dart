import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/customer_detail/customer_detail_bloc.dart';
import '../../blocs/customer_detail/customer_detail_event.dart';
import '../../blocs/customer_detail/customer_detail_state.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_event.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';

class CustomerDetailPage extends StatefulWidget {
  final String customerId;
  final String storeId;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
    required this.storeId,
  });

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<CustomerDetailBloc>().add(
      CustomerDetailRequested(storeId: widget.storeId, customerId: widget.customerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Клиент')),
      body: BlocBuilder<CustomerDetailBloc, CustomerDetailState>(
        builder: (context, state) {
          if (state is CustomerDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CustomerDetailError) {
            return Center(child: Text(state.message));
          }
          if (state is CustomerDetailLoaded) {
            final customer = state.customer;
            final recentSales = state.recentSales;
            return RefreshIndicator(
              onRefresh: () async {
                context.read<CustomerDetailBloc>().add(
                  CustomerDetailRequested(storeId: widget.storeId, customerId: widget.customerId),
                );
              },
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        if (customer.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(customer.phone!, style: const TextStyle(color: AppColors.lightTextSecondary)),
                        ],
                        if (customer.email != null) ...[
                          const SizedBox(height: 2),
                          Text(customer.email!, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13)),
                        ],
                        if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppConstants.spacingSm),
                          Text(customer.notes!, style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary), textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (customer.phone != null && customer.phone!.isNotEmpty)
                        _ActionButton(
                          icon: Icons.phone_outlined,
                          label: 'Звонок',
                          color: AppColors.success,
                          onTap: () => _launchPhone(customer.phone!),
                        ),
                      if (customer.phone != null && customer.phone!.isNotEmpty)
                        _ActionButton(
                          icon: Icons.message_outlined,
                          label: 'СМС',
                          color: const Color(0xFF2196F3),
                          onTap: () => _launchSms(customer.phone!),
                        ),
                      _ActionButton(
                        icon: Icons.shopping_cart_outlined,
                        label: 'Продажа',
                        color: AppColors.primary,
                        onTap: () {
                          context.read<CartBloc>().add(CartCustomerSelected(
                            customerId: customer.id,
                            customerName: customer.name,
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Клиент ${customer.name} выбран для продажи')),
                          );
                          context.go('/home');
                        },
                      ),
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Изменить',
                        color: AppColors.lightTextSecondary,
                        onTap: () => _showEditCustomerDialog(customer),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          child: Column(
                            children: [
                              const Text('Потрачено', style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                              const SizedBox(height: 4),
                              Text('${customer.totalSpent.toStringAsFixed(0)} TJS', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            children: [
                              const Text('Долг', style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                              const SizedBox(height: 4),
                              Text('${customer.debt.toStringAsFixed(0)} TJS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: customer.debt > 0 ? AppColors.error : AppColors.lightTextPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            children: [
                              const Text('Баллы', style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                              const SizedBox(height: 4),
                              Text('${customer.loyaltyPoints}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  if (customer.debt > 0)
                    AppButton(
                      text: 'Посмотреть долги',
                      type: AppButtonType.outlined,
                      icon: Icons.account_balance_wallet,
                      onPressed: () => context.push('/debts/customer', extra: {
                        'storeId': widget.storeId,
                        'customerId': widget.customerId,
                        'customerName': customer.name,
                      }),
                    ),
                  const SizedBox(height: AppConstants.spacingLg),

                  const Text('Последние покупки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppConstants.spacingSm),
                  if (recentSales.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppConstants.spacingXl),
                        child: Text('Нет покупок', style: TextStyle(color: AppColors.lightTextSecondary)),
                      ),
                    )
                  else
                    ...recentSales.map((sale) => Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                      child: AppCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Чек #${sale['receiptNo'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  _formatDate(sale['createdAt'] as String? ?? ''),
                                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${((sale['total'] as num?) ?? 0).toStringAsFixed(2)} TJS', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  _paymentLabel(sale['paymentType'] as String? ?? ''),
                                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _paymentLabel(String type) {
    switch (type) {
      case 'CASH': return 'Наличные';
      case 'CARD': return 'Карта';
      case 'CREDIT': return 'В долг';
      default: return type;
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchSms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showEditCustomerDialog(dynamic customer) {
    // TODO: Implement edit customer dialog or navigate to edit page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Редактирование клиента скоро будет доступно')),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
