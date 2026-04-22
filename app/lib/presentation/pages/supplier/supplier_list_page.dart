import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../domain/repositories/supplier_repository.dart';
import '../../../injection.dart';
import '../../blocs/supplier/supplier_list_bloc.dart';
import '../../blocs/supplier/supplier_list_event.dart';
import '../../blocs/supplier/supplier_list_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

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
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadSuppliers() {
    context.read<SupplierListBloc>().add(SupplierListLoadRequested(
      storeId: _getStoreId(),
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    ));
  }

  void _showAddSupplierDialog() {
    _nameController.clear();
    _phoneController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый поставщик'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Название',
                hintText: 'Введите название поставщика',
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
              final messenger = ScaffoldMessenger.of(context);
              try {
                await sl<SupplierRepository>().createSupplier(
                  _getStoreId(),
                  {'name': name, if (phone.isNotEmpty) 'phone': phone},
                );
                navigator.pop();
                if (!mounted) return;
                _loadSuppliers();
              } catch (e) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
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
    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddSupplierDialog,
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
                  IconButton(tooltip: 'Назад', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                  const Text('Поставщики',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Добавить поставщика',
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: _showAddSupplierDialog,
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
                  onChanged: (_) => _loadSuppliers(),
                  decoration: InputDecoration(
                    hintText: 'Поиск поставщика',
                    hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: context.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Supplier list
            Expanded(
              child: BlocBuilder<SupplierListBloc, SupplierListState>(
                builder: (context, state) {
                  if (state is SupplierListLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SupplierListError) {
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _loadSuppliers,
                    );
                  }
                  if (state is SupplierListLoaded) {
                    final suppliers = state.suppliers;
                    if (suppliers.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'Поставщиков пока нет',
                        subtitle: 'Добавьте первого поставщика, чтобы отслеживать поставки и долги',
                        buttonText: 'Добавить поставщика',
                        onButtonPressed: _showAddSupplierDialog,
                      );
                    }

                    final totalDebt = suppliers.fold<double>(0, (sum, s) => sum + s.debt);

                    return RefreshIndicator(
                      onRefresh: () async => _loadSuppliers(),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Total debt card (orange)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: context.warningBg,
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: Column(
                              children: [
                                const Text('Наш долг',
                                  style: TextStyle(fontSize: 13, color: AppColors.warning)),
                                const SizedBox(height: 4),
                                Text(_formatPrice(totalDebt),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Supplier cards
                          ...suppliers.map((supplier) => GestureDetector(
                            onTap: () => context.push('/suppliers/${supplier.id}', extra: _getStoreId()),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surface,
                                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                    ),
                                    child: const Icon(Icons.factory_outlined, size: 20, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(supplier.name,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                        if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(supplier.phone!,
                                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        supplier.debt > 0 ? _formatPrice(supplier.debt) : '0 TJS',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: supplier.debt > 0 ? AppColors.warning : AppColors.success,
                                        ),
                                      ),
                                      if (supplier.debt <= 0)
                                        const Icon(Icons.check, size: 14, color: AppColors.success),
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
}
