import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/router/route_names.dart';
import '../../../injection.dart';
import '../../blocs/investment/investment_bloc.dart';
import '../../blocs/investment/investment_event.dart';
import '../../blocs/investment/investment_state.dart';

class InvestmentListPage extends StatefulWidget {
  final String storeId;
  const InvestmentListPage({super.key, required this.storeId});
  @override
  State<InvestmentListPage> createState() => _InvestmentListPageState();
}

class _InvestmentListPageState extends State<InvestmentListPage> {
  String? _selectedStatus;

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  final _statuses = [
    (null, 'Все'),
    ('ACTIVE', 'Активно'),
    ('COMPLETED', 'Завершено'),
    ('CANCELLED', 'Отменено'),
  ];

  void _loadInvestments(BuildContext context) {
    context.read<InvestmentBloc>().add(InvestmentListRequested(
      storeId: widget.storeId,
      status: _selectedStatus,
    ));
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'ACTIVE':
        return context.success;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
        return context.danger;
      default:
        return context.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Активно';
      case 'COMPLETED':
        return 'Завершено';
      case 'CANCELLED':
        return 'Отменено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvestmentBloc>()
        ..add(InvestmentListRequested(storeId: widget.storeId)),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(title: const Text('Вложения')),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                final result = await context.push(
                  RouteNames.addInvestment,
                  extra: widget.storeId,
                );
                if (result == true && context.mounted) {
                  _loadInvestments(context);
                }
              },
              child: const Icon(Icons.add, color: AppColors.onPrimary),
            ),
            body: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingSm,
                    ),
                    itemCount: _statuses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final s = _statuses[index];
                      final isSelected = s.$1 == _selectedStatus;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedStatus = s.$1);
                          _loadInvestments(context);
                        },
                        child: Chip(
                          label: Text(s.$2),
                          backgroundColor: isSelected
                              ? AppColors.primary
                              : context.surface,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.onPrimary
                                : context.textSecondary,
                            fontSize: 13,
                          ),
                          side: BorderSide.none,
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: BlocConsumer<InvestmentBloc, InvestmentState>(
                    listener: (context, state) {
                      if (state is InvestmentActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: context.success,
                          ),
                        );
                        _loadInvestments(context);
                      }
                      if (state is InvestmentError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: context.danger,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is InvestmentLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is InvestmentLoaded) {
                        if (state.investments.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up,
                                    size: 64, color: AppColors.disabled),
                                const SizedBox(height: AppConstants.spacingMd),
                                Text('Вложений пока нет',
                                    style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 16)),
                              ],
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async => _loadInvestments(context),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            itemCount: state.investments.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppConstants.spacingSm),
                            itemBuilder: (context, index) {
                              final inv = state.investments[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.surface,
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusMd),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(inv.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${inv.investorName} \u2022 ${DateFormat('dd.MM.yyyy').format(inv.startDate)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors
                                                    .lightTextSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(_formatPrice(inv.amount),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(inv.status, context)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(AppConstants.radiusMd),
                                          ),
                                          child: Text(
                                            _statusLabel(inv.status),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _statusColor(inv.status, context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
