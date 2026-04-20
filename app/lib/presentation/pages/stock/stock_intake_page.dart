import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/common/barcode_scanner_sheet.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/product.dart';
import '../../blocs/product/product_list_bloc.dart';
import '../../blocs/product/product_list_event.dart';
import '../../blocs/product/product_list_state.dart';
import '../../blocs/stock/stock_intake_bloc.dart';
import '../../blocs/stock/stock_intake_event.dart';
import '../../blocs/stock/stock_intake_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_search_bar.dart';

class StockIntakePage extends StatefulWidget {
  const StockIntakePage({super.key});

  @override
  State<StockIntakePage> createState() => _StockIntakePageState();
}

class _StockIntakePageState extends State<StockIntakePage> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      final storeId = storeState.selectedStore!.id;
      context.read<ProductListBloc>().add(ProductListLoadRequested(storeId: storeId));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  String? _getStoreId() {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      return storeState.selectedStore!.id;
    }
    return null;
  }

  Currency _getCurrency() {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      return Currency.values.firstWhere(
        (c) => c.name == storeState.selectedStore!.currency,
        orElse: () => Currency.tjs,
      );
    }
    return Currency.tjs;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockIntakeBloc, StockIntakeState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Приход успешно оформлен'),
              backgroundColor: AppColors.success,
            ),
          );
          context.read<StockIntakeBloc>().add(StockIntakeReset());
          context.pop();
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
          title: const Text('Приход товара'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: AppSearchBar(
                controller: _searchController,
                hint: 'Найти товар для прихода',
                onChanged: (query) {
                  setState(() => _isSearching = query.isNotEmpty);
                  context.read<ProductListBloc>().add(ProductListSearchChanged(query));
                },
                onScanTap: () {
                  BarcodeScannerSheet.show(
                    context,
                    onScanned: (barcode) {
                      context.read<ProductListBloc>().add(ProductListSearchChanged(barcode));
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<StockIntakeBloc, StockIntakeState>(
                builder: (context, state) {
                  if (state.selectedProduct != null) {
                    return _buildIntakeForm(state);
                  }

                  if (_isSearching) {
                    return _buildProductSearchResults();
                  }

                  return _buildEmptyState();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory, size: 64, color: AppColors.disabled),
          const SizedBox(height: 16),
          Text(
            'Найдите товар для оформления прихода',
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearchResults() {
    return BlocBuilder<ProductListBloc, ProductListState>(
      builder: (context, state) {
        if (state is ProductListLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProductListError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: TextStyle(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (state is ProductListLoaded) {
          if (state.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: AppColors.disabled),
                  const SizedBox(height: 16),
                  Text(
                    'Товары не найдены',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
            itemCount: state.products.length,
            itemBuilder: (context, index) {
              final product = state.products[index];
              return _buildProductItem(product);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProductItem(Product product) {
    final currency = _getCurrency();

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: ListTile(
        leading: product.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: Image.network(
                  product.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 48,
                      height: 48,
                      color: context.bg,
                      child: const Icon(Icons.inventory_2, color: AppColors.disabled),
                    );
                  },
                ),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.bg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(Icons.inventory_2, color: AppColors.disabled),
              ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Formatters.price(product.sellPrice, currency: currency)),
            Text(
              'Остаток: ${product.quantity} ${_getUnitDisplayName(product.unit)}',
              style: TextStyle(
                fontSize: 12,
                color: product.isLowStock ? AppColors.warning : context.textSecondary,
              ),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          context.read<StockIntakeBloc>().add(StockIntakeSelectProduct(product));
          _quantityController.clear();
          _unitCostController.text = product.costPrice?.toString() ?? '';
        },
      ),
    );
  }

  Widget _buildIntakeForm(StockIntakeState state) {
    final product = state.selectedProduct!;
    final currency = _getCurrency();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                children: [
                  if (product.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      child: Image.network(
                        product.imageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 64,
                            height: 64,
                            color: context.bg,
                            child: const Icon(Icons.inventory_2, size: 32, color: AppColors.disabled),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.bg,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: const Icon(Icons.inventory_2, size: 32, color: AppColors.disabled),
                    ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Цена: ${Formatters.price(product.sellPrice, currency: currency)}',
                          style: TextStyle(color: context.textSecondary),
                        ),
                        Text(
                          'Остаток: ${product.quantity} ${_getUnitDisplayName(product.unit)}',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      context.read<StockIntakeBloc>().add(StockIntakeReset());
                      _quantityController.clear();
                      _unitCostController.clear();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const Text(
            'Количество',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Введите количество',
              suffixText: _getUnitDisplayName(product.unit),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              final quantity = int.tryParse(value) ?? 0;
              context.read<StockIntakeBloc>().add(StockIntakeSetQuantity(quantity));
            },
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const Text(
            'Себестоимость (за единицу)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          TextField(
            controller: _unitCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: 'Введите себестоимость',
              suffixText: currency.symbol,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              final unitCost = double.tryParse(value) ?? 0.0;
              context.read<StockIntakeBloc>().add(StockIntakeSetUnitCost(unitCost));
            },
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итоговая стоимость',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.price(state.totalCost, currency: currency),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingXl),
          AppButton(
            text: 'Сохранить',
            onPressed: state.canSubmit && !state.isSubmitting
                ? () {
                    final storeId = _getStoreId();
                    if (storeId != null) {
                      context.read<StockIntakeBloc>().add(StockIntakeSubmit(storeId: storeId));
                    }
                  }
                : null,
            isLoading: state.isSubmitting,
          ),
        ],
      ),
    );
  }

  String _getUnitDisplayName(String unit) {
    try {
      final productUnit = ProductUnit.values.firstWhere(
        (u) => u.name.toUpperCase() == unit.toUpperCase(),
        orElse: () => ProductUnit.pcs,
      );
      return productUnit.displayName;
    } catch (e) {
      return unit;
    }
  }
}
