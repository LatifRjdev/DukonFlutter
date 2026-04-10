import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../injection.dart';
import '../../blocs/supplier_detail/supplier_detail_bloc.dart';
import '../../blocs/supplier_detail/supplier_detail_event.dart';
import '../../blocs/supplier_detail/supplier_detail_state.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';

class SupplierDetailPage extends StatelessWidget {
  final String supplierId;
  final String storeId;

  const SupplierDetailPage({
    super.key,
    required this.supplierId,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SupplierDetailBloc>(
      create: (_) => sl<SupplierDetailBloc>()
        ..add(SupplierDetailRequested(storeId: storeId, supplierId: supplierId)),
      child: _SupplierDetailView(storeId: storeId, supplierId: supplierId),
    );
  }
}

class _SupplierDetailView extends StatelessWidget {
  final String storeId;
  final String supplierId;

  const _SupplierDetailView({required this.storeId, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupplierDetailBloc, SupplierDetailState>(
      builder: (context, state) {
        if (state is SupplierDetailLoading || state is SupplierDetailInitial) {
          return Scaffold(
            appBar: AppBar(title: const Text('Поставщик')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state is SupplierDetailError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Поставщик')),
            body: Center(child: Text(state.message)),
          );
        }
        if (state is SupplierDetailLoaded) {
          final supplier = state.supplier;

          return Scaffold(
            appBar: AppBar(title: Text(supplier.name)),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<SupplierDetailBloc>().add(
                  SupplierDetailRequested(storeId: storeId, supplierId: supplierId),
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
                          backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                          child: Text(
                            supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.warning),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        Text(supplier.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        if (supplier.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(supplier.phone!, style: const TextStyle(color: AppColors.lightTextSecondary)),
                        ],
                        if (supplier.email != null) ...[
                          const SizedBox(height: 2),
                          Text(supplier.email!, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13)),
                        ],
                        if (supplier.address != null && supplier.address!.isNotEmpty) ...[
                          const SizedBox(height: AppConstants.spacingSm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, size: 16, color: AppColors.lightTextSecondary),
                              const SizedBox(width: 4),
                              Text(supplier.address!, style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                            ],
                          ),
                        ],
                        if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppConstants.spacingSm),
                          Text(supplier.notes!, style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary), textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (supplier.phone != null && supplier.phone!.isNotEmpty)
                        _ActionButton(
                          icon: Icons.phone_outlined,
                          label: 'Звонок',
                          color: AppColors.success,
                          onTap: () => _launchPhone(supplier.phone!),
                        ),
                      if (supplier.phone != null && supplier.phone!.isNotEmpty)
                        _ActionButton(
                          icon: Icons.message_outlined,
                          label: 'СМС',
                          color: AppColors.info,
                          onTap: () => _launchSms(supplier.phone!),
                        ),
                      if (supplier.debt > 0)
                        _ActionButton(
                          icon: Icons.payment_outlined,
                          label: 'Оплата',
                          color: AppColors.warning,
                          onTap: () => context.push('/debts/supplier', extra: {
                            'storeId': storeId,
                            'supplierId': supplierId,
                            'supplierName': supplier.name,
                          }),
                        ),
                      _ActionButton(
                        icon: Icons.add_shopping_cart_outlined,
                        label: 'Заказ',
                        color: AppColors.primary,
                        onTap: () => context.push('/stock/intake'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Наш долг', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(
                          '${supplier.debt.toStringAsFixed(2)} TJS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: supplier.debt > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  if (supplier.debt > 0)
                    AppButton(
                      text: 'Записать оплату',
                      icon: Icons.payment,
                      onPressed: () => context.push('/debts/supplier', extra: {
                        'storeId': storeId,
                        'supplierId': supplierId,
                        'supplierName': supplier.name,
                      }),
                    ),
                ],
              ),
            ),
          );
        }

        // Fallback
        return Scaffold(
          appBar: AppBar(title: const Text('Поставщик')),
          body: const Center(child: Text('Данные не найдены')),
        );
      },
    );
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
