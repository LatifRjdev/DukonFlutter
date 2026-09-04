import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_event.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../widgets/payroll/month_selector.dart';
import '../../widgets/payroll/payroll_staff_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class PayrollPage extends StatefulWidget {
  final String storeId;
  const PayrollPage({super.key, required this.storeId});
  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late int _selectedMonth;
  late int _selectedYear;

  // Every payroll action (pay individual/all, add/remove adjustment,
  // calculate) re-emits PayrollLoading while it runs, which used to tear
  // down whichever view (periods list or period detail) was on screen down
  // to a bare spinner. Track the last successfully loaded view so a
  // background action keeps showing it (with action buttons disabled via
  // `busy` instead of hidden), and so a failed action's Retry button
  // reloads the *same* view instead of always falling back to the periods
  // list (SPEC.md audit finding, post-plan).
  PayrollState? _lastLoadedState;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
  }

  void _loadData() {
    context.read<PayrollBloc>().add(LoadPayrollPeriods(storeId: widget.storeId));
  }

  void _retryLastLoad() {
    final last = _lastLoadedState;
    if (last is PayrollPeriodDetailLoaded) {
      _loadPeriodDetail(last.period.id);
    } else {
      _loadData();
    }
  }

  void _onMonthChanged(({int month, int year}) value) {
    setState(() {
      _selectedMonth = value.month;
      _selectedYear = value.year;
    });
  }

  void _calculate() {
    context.read<PayrollBloc>().add(CalculatePayroll(
      storeId: widget.storeId,
      month: _selectedMonth,
      year: _selectedYear,
    ));
  }

  void _loadPeriodDetail(String periodId) {
    context.read<PayrollBloc>().add(LoadPayrollPeriod(
      storeId: widget.storeId,
      periodId: periodId,
    ));
  }

  void _payAll(String periodId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выплатить всем'),
        content: const Text('Вы уверены, что хотите выплатить зарплату всем сотрудникам?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PayrollBloc>().add(PayAll(
                storeId: widget.storeId,
                periodId: periodId,
              ));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Выплатить', style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _payIndividual(String periodId, String payrollId) {
    context.read<PayrollBloc>().add(PayIndividual(
      storeId: widget.storeId,
      periodId: periodId,
      payrollId: payrollId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Зарплата')),
      body: BlocConsumer<PayrollBloc, PayrollState>(
        listener: (context, state) {
          if (state is PayrollError) {
            AppSnackbar.error(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is PayrollPeriodsLoaded || state is PayrollPeriodDetailLoaded) {
            _lastLoadedState = state;
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: MonthSelector(
                  month: _selectedMonth,
                  year: _selectedYear,
                  onChanged: _onMonthChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
                child: AppButton(
                  text: 'Рассчитать',
                  icon: Icons.calculate,
                  isLoading: state is PayrollLoading,
                  onPressed: _calculate,
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Expanded(child: _buildContent(state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(PayrollState state) {
    if (state is PayrollLoading) {
      final last = _lastLoadedState;
      if (last == null) {
        return const Center(child: CircularProgressIndicator());
      }
      // A background action (pay/adjustment/calculate) is refreshing this
      // view — keep showing the last-known content, with action buttons
      // disabled, instead of flashing a bare spinner over it.
      return last is PayrollPeriodDetailLoaded
          ? _buildPeriodDetail(last, busy: true)
          : _buildPeriodsList(last as PayrollPeriodsLoaded, busy: true);
    }

    if (state is PayrollPeriodsLoaded) {
      return _buildPeriodsList(state, busy: false);
    }

    if (state is PayrollPeriodDetailLoaded) {
      return _buildPeriodDetail(state, busy: false);
    }

    if (state is PayrollError) {
      return AppErrorWidget(
        message: state.message,
        onRetry: _retryLastLoad,
      );
    }

    return const AppEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Расчёт зарплаты',
      subtitle: 'Выберите месяц и нажмите "Рассчитать" для расчёта зарплаты сотрудников',
    );
  }

  Widget _buildPeriodsList(PayrollPeriodsLoaded state, {required bool busy}) {
    if (state.periods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: AppConstants.spacingXxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.disabled),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                'Нет данных по зарплате',
                style: TextStyle(color: context.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                'Выберите месяц и нажмите "Рассчитать"',
                style: TextStyle(color: context.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
        itemCount: state.periods.length,
        itemBuilder: (context, index) {
          final period = state.periods[index];
          return _PeriodCard(
            month: period.month,
            year: period.year,
            status: period.status,
            totalAmount: period.totalAmount,
            paidAmount: period.paidAmount,
            staffCount: period.staffCount,
            onTap: busy ? null : () => _loadPeriodDetail(period.id),
          );
        },
      ),
    );
  }

  Widget _buildPeriodDetail(PayrollPeriodDetailLoaded state, {required bool busy}) {
    final period = state.period;
    final hasUnpaid = period.payrolls.any((e) => !e.isPaid);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
          child: Row(
            children: [
              IconButton(
                onPressed: busy ? null : _loadData,
                icon: const Icon(Icons.arrow_back),
                tooltip: AppLocalizations.of(context)!.back,
              ),
              Expanded(
                child: Text(
                  'Итого: ${period.totalAmount.toStringAsFixed(2)} TJS',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: busy
                    ? null
                    : () => context.push(
                        '/payroll/${period.id}/adjustment',
                        extra: {'storeId': widget.storeId, 'periodId': period.id},
                      ),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                tooltip: 'Добавить корректировку',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadPeriodDetail(period.id),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
              children: [
                ...period.payrolls.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                  child: PayrollStaffCard(
                    entry: entry,
                    onTap: busy ? null : () => context.push('/staff/${entry.staffId}', extra: widget.storeId),
                    onPay: (entry.isPaid || busy)
                        ? null
                        : () => _payIndividual(period.id, entry.id),
                  ),
                )),
                if (period.payrolls.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppConstants.spacingXxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: AppColors.disabled),
                          const SizedBox(height: AppConstants.spacingMd),
                          Text(
                            'Нет данных по сотрудникам',
                            style: TextStyle(color: context.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppConstants.spacingLg),
              ],
            ),
          ),
        ),
        if (hasUnpaid)
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: AppButton(
              text: 'Выплатить всем',
              icon: Icons.payments_outlined,
              isLoading: busy,
              onPressed: () => _payAll(period.id),
            ),
          ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final int month;
  final int year;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final int staffCount;
  final VoidCallback? onTap;

  const _PeriodCard({
    required this.month,
    required this.year,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.staffCount,
    this.onTap,
  });

  static const _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  String _statusLabel(String status) {
    switch (status) {
      case 'CALCULATED':
        return 'Рассчитано';
      case 'PARTIALLY_PAID':
        return 'Частично оплачено';
      case 'PAID':
        return 'Оплачено';
      default:
        return status;
    }
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'CALCULATED':
        return AppColors.info;
      case 'PARTIALLY_PAID':
        return AppColors.warning;
      case 'PAID':
        return AppColors.success;
      default:
        return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      elevation: AppConstants.cardElevation,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_monthNames[month - 1]} $year',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status, context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status, context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Divider(height: 1, color: context.border),
              const SizedBox(height: AppConstants.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${totalAmount.toStringAsFixed(2)} TJS',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Итого',
                          style: TextStyle(fontSize: 12, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${paidAmount.toStringAsFixed(2)} TJS',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          'Выплачено',
                          style: TextStyle(fontSize: 12, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 16, color: context.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '$staffCount',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        'Сотрудники',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
