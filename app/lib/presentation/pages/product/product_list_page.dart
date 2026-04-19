import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/barcode_scanner_sheet.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/enums.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_shadows.dart';
import '../../widgets/common/app_chip.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../domain/entities/product.dart';
import '../../blocs/category/category_bloc.dart';
import '../../blocs/category/category_event.dart';
import '../../blocs/product/product_list_bloc.dart';
import '../../blocs/product/product_list_event.dart';
import '../../blocs/product/product_list_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

enum _StockFilter { all, inStock, lowStock, outOfStock }

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _searchController = TextEditingController();
  _StockFilter _stockFilter = _StockFilter.all;
  bool _loaded = false;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      _loaded = true;
      final storeId = storeState.selectedStore!.id;
      context.read<ProductListBloc>().add(ProductListLoadRequested(storeId: storeId));
      context.read<CategoryBloc>().add(CategoryLoadRequested(storeId));
    }
  }

  List<Product> _filterByStock(List<Product> products) {
    switch (_stockFilter) {
      case _StockFilter.all:
        return products;
      case _StockFilter.inStock:
        return products.where((p) => p.quantity > p.minQuantity).toList();
      case _StockFilter.lowStock:
        return products.where((p) => p.isLowStock).toList();
      case _StockFilter.outOfStock:
        return products.where((p) => p.isOutOfStock).toList();
    }
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StoreBloc, StoreState>(
      listener: (context, state) {
        if (state is StoreLoaded && !_loaded) {
          _loadData();
        }
      },
      child: Scaffold(
        backgroundColor: context.bg,
        body: SafeArea(
          child: Column(
            children: [
              // Header: "Товары" + "..." + "+"
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  const Text('Товары',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'categories') {
                        context.push('/categories');
                      } else if (value == 'import') {
                        final storeState = context.read<StoreBloc>().state;
                        final storeId = storeState is StoreLoaded
                            ? storeState.selectedStore?.id ?? ''
                            : '';
                        context.push('/products/import', extra: storeId);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'categories',
                        child: Text('Категории'),
                      ),
                      const PopupMenuItem(
                        value: 'import',
                        child: Text('Импорт из Excel'),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: () => context.push('/products/add'),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: AppColors.overlay, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) {
                    context.read<ProductListBloc>().add(ProductListSearchChanged(query));
                  },
                  decoration: InputDecoration(
                    hintText: 'Поиск товара',
                    hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: context.textSecondary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.qr_code_scanner, color: context.textSecondary),
                          onPressed: () {
                            BarcodeScannerSheet.show(
                              context,
                              onScanned: (barcode) {
                                _searchController.text = barcode;
                                context.read<ProductListBloc>().add(ProductListSearchChanged(barcode));
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.tune, color: _showFilters ? context.primary : context.textSecondary),
                          onPressed: () {
                            setState(() => _showFilters = !_showFilters);
                          },
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Stock filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    AppChip(
                      label: 'Все',
                      isSelected: _stockFilter == _StockFilter.all,
                      onTap: () => setState(() => _stockFilter = _StockFilter.all),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'В наличии',
                      isSelected: _stockFilter == _StockFilter.inStock,
                      onTap: () => setState(() => _stockFilter = _StockFilter.inStock),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Заканчивается',
                      isSelected: _stockFilter == _StockFilter.lowStock,
                      onTap: () => setState(() => _stockFilter = _StockFilter.lowStock),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Нет в наличии',
                      isSelected: _stockFilter == _StockFilter.outOfStock,
                      onTap: () => setState(() => _stockFilter = _StockFilter.outOfStock),
                    ),
                  ],
                ),
              ),
            ),

            // Product list
            Expanded(
              child: BlocBuilder<ProductListBloc, ProductListState>(
                builder: (context, state) {
                  if (state is ProductListLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ProductListError) {
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _loadData,
                    );
                  }
                  if (state is ProductListLoaded) {
                    final filtered = _filterByStock(state.products);
                    if (filtered.isEmpty) {
                      final isEmptyOverall = state.products.isEmpty;
                      return RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: AppEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: isEmptyOverall ? 'Нет товаров' : 'Нет товаров по фильтру',
                                subtitle: isEmptyOverall
                                    ? 'Добавьте первый товар в каталог'
                                    : 'Попробуйте изменить фильтр или поисковый запрос',
                                buttonText: isEmptyOverall ? 'Добавить товар' : null,
                                onButtonPressed: isEmptyOverall
                                    ? () => context.push(RouteNames.addProduct)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Calculate totals for footer
                    double totalValue = 0;
                    double totalCost = 0;
                    for (final p in state.products) {
                      totalValue += p.sellPrice * p.quantity;
                      if (p.costPrice != null) {
                        totalCost += p.costPrice! * p.quantity;
                      }
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async => _loadData(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) =>
                                  _ProductCard(product: filtered[index], formatPrice: _formatPrice),
                            ),
                          ),
                        ),
                        // Sticky footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: context.surface,
                            boxShadow: const [
                              BoxShadow(color: AppColors.overlay, blurRadius: 8, offset: Offset(0, -2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Общая сумма',
                                      style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                    Text(_formatPrice(totalValue),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 32, color: context.border),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Себестоимость',
                                      style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                    Text(_formatPrice(totalCost),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String Function(double) formatPrice;

  const _ProductCard({required this.product, required this.formatPrice});

  @override
  Widget build(BuildContext context) {
    String unitName;
    try {
      final productUnit = ProductUnit.values.firstWhere(
        (u) => u.name.toUpperCase() == product.unit.toUpperCase(),
        orElse: () => ProductUnit.pcs,
      );
      unitName = productUnit.displayName;
    } catch (e) {
      unitName = product.unit;
    }

    Color stockColor;
    if (product.isOutOfStock) {
      stockColor = AppColors.error;
    } else if (product.isLowStock) {
      stockColor = AppColors.warning;
    } else {
      stockColor = AppColors.success;
    }

    return GestureDetector(
      onTap: () => context.push('/products/${product.id}', extra: product),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.light ? AppShadows.sm : null,
        ),
        child: Row(
          children: [
            // Product photo 64x64
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: product.imageUrl != null
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.image_outlined, size: 28, color: AppColors.disabled)),
                    )
                  : const Center(child: Icon(Icons.inventory_2_outlined, size: 28, color: AppColors.disabled)),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                  if (product.sku != null && product.sku!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Арт: ${product.sku}',
                      style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('На складе: ',
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                      Text('${product.quantity} $unitName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: stockColor,
                        )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Prices right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(product.sellPrice),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  )),
                if (product.costPrice != null) ...[
                  const SizedBox(height: 2),
                  Text(formatPrice(product.costPrice!),
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
