import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../domain/entities/expense.dart';
import '../../blocs/expense/expense_bloc.dart';
import '../../blocs/expense/expense_event.dart';
import '../../blocs/expense/expense_state.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../widgets/finance/expense_card.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class ExpenseListPage extends StatefulWidget {
  final String storeId;
  const ExpenseListPage({super.key, required this.storeId});
  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  String? _selectedCategory;

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  String _formatDateHeader(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDay = DateTime(date.year, date.month, date.day);

    if (expenseDay == today) return l10n.today;
    if (expenseDay == yesterday) return l10n.yesterday;
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Map<String, List<Expense>> _groupExpensesByDate(List<Expense> expenses, AppLocalizations l10n) {
    final grouped = <String, List<Expense>>{};
    for (final expense in expenses) {
      final key = _formatDateHeader(expense.date, l10n);
      grouped.putIfAbsent(key, () => []).add(expense);
    }
    return grouped;
  }

  List<(String?, String)> _categoryOptions(AppLocalizations l10n) => [
    (null, l10n.all),
    ('PURCHASE', l10n.purchase),
    ('RENT', l10n.rent),
    ('SALARY', l10n.salary),
    ('UTILITIES', l10n.utilities),
    ('TRANSPORT', l10n.transport),
    ('MARKETING', l10n.marketing),
    ('OTHER', l10n.other),
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    context.read<ExpenseBloc>().add(ExpenseListRequested(
      storeId: widget.storeId,
      category: _selectedCategory,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categoryOptions = _categoryOptions(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.expenses)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/finance/expenses/add', extra: widget.storeId),
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingSm),
              itemCount: categoryOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categoryOptions[index];
                final isSelected = cat.$1 == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat.$1);
                    _loadExpenses();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    child: Chip(
                      label: Text(cat.$2),
                      backgroundColor: isSelected ? AppColors.primary : context.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.onPrimary : context.textSecondary,
                        fontSize: 13,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<ExpenseBloc, ExpenseState>(
              builder: (context, state) {
                if (state is ExpenseLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ExpenseError) {
                  return AppErrorWidget(
                    message: state.message,
                    onRetry: _loadExpenses,
                  );
                }
                if (state is ExpenseLoaded) {
                  if (state.expenses.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.noExpenses,
                      subtitle: l10n.expenseListEmptySubtitle,
                      buttonText: l10n.addExpense,
                      onButtonPressed: () => context.push('/finance/expenses/add', extra: widget.storeId),
                    );
                  }
                  final expenses = state.expenses;
                  final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final todayAmount = expenses
                      .where((e) => DateTime(e.date.year, e.date.month, e.date.day) == today)
                      .fold<double>(0, (sum, e) => sum + e.amount);
                  final grouped = _groupExpensesByDate(expenses, l10n);
                  final dateKeys = grouped.keys.toList();

                  return RefreshIndicator(
                    onRefresh: () async => _loadExpenses(),
                    child: ListView(
                      padding: const EdgeInsets.all(AppConstants.spacingMd),
                      children: [
                        // Summary card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(l10n.today, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('-${_formatPrice(todayAmount)}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.danger)),
                                ],
                              ),
                              Container(width: 1, height: 40, color: context.border),
                              Column(
                                children: [
                                  Text(l10n.expenseListForPeriod, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('-${_formatPrice(totalAmount)}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.danger)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Grouped expenses
                        for (final dateKey in dateKeys) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 8),
                            child: Text(dateKey,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                          ),
                          for (final expense in grouped[dateKey]!) ...[
                            ExpenseCard(
                              expense: expense,
                              onDelete: () {
                                context.read<ExpenseBloc>().add(ExpenseDeleteRequested(storeId: widget.storeId, id: expense.id));
                              },
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                          ],
                        ],
                      ],
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
  }
}
