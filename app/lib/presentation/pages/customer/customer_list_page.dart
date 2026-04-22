import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../domain/repositories/customer_repository.dart';
import '../../../injection.dart';
import '../../blocs/customer/customer_list_bloc.dart';
import '../../blocs/customer/customer_list_event.dart';
import '../../blocs/customer/customer_list_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import 'package:dokonpro/l10n/app_localizations.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedFilter = 'all';

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  String _getStoreId() {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? storeState.selectedStore?.id ?? '' : '';
  }

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadCustomers() {
    context.read<CustomerListBloc>().add(CustomerListLoadRequested(
      storeId: _getStoreId(),
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    ));
  }

  void _showAddCustomerDialog() {
    _nameController.clear();
    _phoneController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый клиент'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Имя',
                hintText: 'Введите имя клиента',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Телефон',
                hintText: '+992 XX XXX XXXX',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              final phone = _phoneController.text.trim();
              // Capture refs before the await so we do not touch BuildContext
              // across the async gap (FE-P1-003).
              final navigator = Navigator.of(dialogContext);
              // Pre-capture BuildContext-derived objects before the
              // async gap to satisfy use_build_context_synchronously.
              final messenger = ScaffoldMessenger.of(context);
              final view = View.of(context);
              final dir = Directionality.of(context);
              try {
                await sl<CustomerRepository>().createCustomer(
                  _getStoreId(),
                  {'name': name, if (phone.isNotEmpty) 'phone': phone},
                );
                navigator.pop();
                if (!mounted) return;
                _loadCustomers();
              } catch (e) {
                navigator.pop();
                final msg = 'Ошибка: $e';
                messenger.showSnackBar(SnackBar(
                  content: Text(msg),
                  backgroundColor: AppColors.error,
                ));
                SemanticsService.sendAnnouncement(view, msg, dir);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(tooltip: l10n.back, icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                  const Text('Клиенты',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.a11yAddClient,
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: _showAddCustomerDialog,
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadCustomers(),
                  decoration: InputDecoration(
                    hintText: 'Поиск клиента',
                    hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: context.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip('Все', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('С долгом', 'debt'),
                    const SizedBox(width: 8),
                    _filterChip('VIP', 'vip'),
                    const SizedBox(width: 8),
                    _filterChip('Новые', 'new'),
                  ],
                ),
              ),
            ),

            // Customer list
            Expanded(
              child: BlocBuilder<CustomerListBloc, CustomerListState>(
                builder: (context, state) {
                  if (state is CustomerListLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is CustomerListError) {
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _loadCustomers,
                    );
                  }
                  if (state is CustomerListLoaded) {
                    final customers = state.customers;
                    if (customers.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.people_outline,
                        title: 'Клиентов пока нет',
                        subtitle: 'Добавьте первого клиента, чтобы отслеживать продажи и долги',
                        buttonText: 'Добавить клиента',
                        onButtonPressed: _showAddCustomerDialog,
                      );
                    }

                    final totalDebt = customers.fold<double>(0, (sum, c) => sum + c.debt);

                    return RefreshIndicator(
                      onRefresh: () async => _loadCustomers(),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Stats card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: Text(
                              '${customers.length} клиентов  |  Долг: ${_formatPrice(totalDebt)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Customer cards
                          ...customers.map((customer) => GestureDetector(
                            onTap: () => context.push('/customers/${customer.id}', extra: _getStoreId()),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surface,
                                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(customer.name,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                            ),
                                            if (customer.loyaltyPoints > 1000 || customer.totalSpent > 50000) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warning.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star, size: 10, color: AppColors.warning),
                                                    SizedBox(width: 2),
                                                    Text('VIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(customer.phone!,
                                            style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                        ],
                                        if (customer.totalSpent > 0) ...[
                                          const SizedBox(height: 2),
                                          Text('Покупок: ${_formatPrice(customer.totalSpent)}',
                                            style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        customer.debt > 0 ? _formatPrice(customer.debt) : 'Нет долга',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: customer.debt > 0 ? AppColors.error : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, color: context.textSecondary, size: 20),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          border: isSelected ? null : Border.all(color: context.border),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.onPrimary : context.textSecondary,
          )),
      ),
    );
  }
}
