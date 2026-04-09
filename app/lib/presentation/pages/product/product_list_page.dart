import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
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
        backgroundColor: AppColors.background,
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
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'categories',
                        child: Text('Категории'),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) {
                    context.read<ProductListBloc>().add(ProductListSearchChanged(query));
                  },
                  decoration: InputDecoration(
                    hintText: 'Поиск товара',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.textSecondary),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Сканер штрихкодов скоро будет доступен')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune, color: AppColors.textSecondary),
                          onPressed: () {},
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
                    _buildFilterChip('Все', _StockFilter.all),
                    const SizedBox(width: 8),
                    _buildFilterChip('В наличии', _StockFilter.inStock),
                    const SizedBox(width: 8),
                    _buildFilterChip('Заканчивается', _StockFilter.lowStock),
                    const SizedBox(width: 8),
                    _buildFilterChip('Нет в наличии', _StockFilter.outOfStock),
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
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                          const SizedBox(height: 16),
                          const Text('Ошибка загрузки',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(state.message,
                            style: const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton(onPressed: _loadData, child: const Text('Повторить')),
                        ],
                      ),
                    );
                  }
                  if (state is ProductListLoaded) {
                    final filtered = _filterByStock(state.products);
                    if (filtered.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.disabled),
                                  const SizedBox(height: 16),
                                  Text(
                                    state.products.isEmpty ? 'Нет товаров' : 'Нет товаров по фильтру',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    state.products.isEmpty
                                        ? 'Добавьте первый товар'
                                        : 'Попробуйте изменить фильтр',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, -2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Общая сумма',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text(_formatPrice(totalValue),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 32, color: AppColors.divider),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Себестоимость',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

  Widget _buildFilterChip(String label, _StockFilter filter) {
    final isSelected = _stockFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _stockFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
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
      stockColor = const Color(0xFFFF9800);
    } else {
      stockColor = AppColors.success;
    }

    return GestureDetector(
      onTap: () => context.push('/products/${product.id}', extra: product),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Product photo 64x64
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
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
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('На складе: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
                if (product.costPrice != null) ...[
                  const SizedBox(height: 2),
                  Text(formatPrice(product.costPrice!),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
