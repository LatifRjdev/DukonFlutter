import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/debt/debt_bloc.dart';
import '../../blocs/debt/debt_event.dart';
import '../../blocs/debt/debt_state.dart';
import '../../widgets/debt/debt_card.dart';

class DebtsOverviewPage extends StatefulWidget {
  final String storeId;

  const DebtsOverviewPage({super.key, required this.storeId});

  @override
  State<DebtsOverviewPage> createState() => _DebtsOverviewPageState();
}

class _DebtsOverviewPageState extends State<DebtsOverviewPage> {
  @override
  void initState() {
    super.initState();
    context.read<DebtBloc>().add(DebtsOverviewRequested(storeId: widget.storeId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DebtBloc, DebtState>(
      builder: (context, state) {
        if (state is DebtLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Долги')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state is DebtError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Долги')),
            body: Center(child: Text(state.message)),
          );
        }
        if (state is DebtsOverviewLoaded) {
          final customers = state.customers;
          final suppliers = state.suppliers;
          final totalCustomerDebt = state.totalCustomerDebt;
          final totalSupplierDebt = state.totalSupplierDebt;

          return Scaffold(
            appBar: AppBar(title: const Text('Долги')),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<DebtBloc>().add(DebtsOverviewRequested(storeId: widget.storeId));
              },
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                          ),
                          child: Column(
                            children: [
                              const Text('Нам должны', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${totalCustomerDebt.toStringAsFixed(2)} TJS',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                          ),
                          child: Column(
                            children: [
                              const Text('Мы должны', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${totalSupplierDebt.toStringAsFixed(2)} TJS',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.warning),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingLg),

                  if (customers.isNotEmpty) ...[
                    const Text('Долги клиентов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppConstants.spacingSm),
                    ...customers.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                      child: DebtCard(
                        name: c['name'] as String? ?? '',
                        debt: (c['debt'] as num? ?? 0).toDouble(),
                        phone: c['phone'] as String?,
                        onTap: () => context.push('/debts/customer', extra: {
                          'storeId': widget.storeId,
                          'customerId': c['id'] as String? ?? '',
                          'customerName': c['name'] as String? ?? '',
                        }),
                      ),
                    )),
                    const SizedBox(height: AppConstants.spacingMd),
                  ],

                  if (suppliers.isNotEmpty) ...[
                    const Text('Наши долги поставщикам', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppConstants.spacingSm),
                    ...suppliers.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                      child: DebtCard(
                        name: s['name'] as String? ?? '',
                        debt: (s['debt'] as num? ?? 0).toDouble(),
                        phone: s['phone'] as String?,
                        isSupplier: true,
                        onTap: () => context.push('/debts/supplier', extra: {
                          'storeId': widget.storeId,
                          'supplierId': s['id'] as String? ?? '',
                          'supplierName': s['name'] as String? ?? '',
                        }),
                      ),
                    )),
                  ],

                  if (customers.isEmpty && suppliers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingXl),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                            const SizedBox(height: AppConstants.spacingMd),
                            const Text('Нет активных долгов', style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // Initial or unexpected state
        return Scaffold(
          appBar: AppBar(title: const Text('Долги')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
