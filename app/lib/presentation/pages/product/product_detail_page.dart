import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/constants/enums.dart';
import '../../../domain/entities/product.dart';
import '../../../injection.dart';
import '../../blocs/product/product_list_bloc.dart';
import '../../blocs/product/product_list_event.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_event.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class ProductDetailPage extends StatelessWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final product = extra is Product ? extra : null;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Товар')),
        body: const Center(child: Text('Товар не найден')),
      );
    }

    final profit = product.profit;
    final margin = product.margin;
    final stockPercent = product.minQuantity > 0
        ? (product.quantity / (product.minQuantity * 5)).clamp(0.0, 1.0)
        : product.quantity > 0
            ? 1.0
            : 0.0;

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

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: ← + "Товар" + edit + "..."
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const Text('Товар',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/products/add', extra: {'product': product, 'isEditing': true}),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteDialog(context, product);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image (~35% screen)
                    Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.28,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Icon(Icons.image_outlined, size: 64, color: AppColors.disabled)),
                            )
                          : const Center(
                              child: Icon(Icons.image_outlined, size: 64, color: AppColors.disabled),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Name + Active badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(product.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.isActive
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.isActive ? 'Активен' : 'Неактивен',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: product.isActive ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4 colored mini-cards 2x2
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetricCard(
                            label: 'Цена продажи',
                            value: _formatPrice(product.sellPrice),
                            bgColor: context.successBg,
                            textColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniMetricCard(
                            label: 'Себестоимость',
                            value: product.costPrice != null
                                ? _formatPrice(product.costPrice!)
                                : '—',
                            bgColor: context.surfaceMuted,
                            textColor: AppColors.gradientMid,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetricCard(
                            label: 'Прибыль',
                            value: profit != null ? _formatPrice(profit) : '—',
                            bgColor: context.warningBg,
                            textColor: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniMetricCard(
                            label: 'Маржа',
                            value: margin != null ? '${margin.toStringAsFixed(0)}%' : '—',
                            bgColor: context.infoBg,
                            textColor: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stock section with progress bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                        boxShadow: AppShadows.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Наличие на складе',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Текущий остаток: ${product.quantity} $unitName',
                                style: const TextStyle(fontSize: 14)),
                              Text('Минимальный: ${product.minQuantity} $unitName',
                                style: TextStyle(fontSize: 13, color: context.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stockPercent,
                              minHeight: 8,
                              backgroundColor: context.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                product.isOutOfStock
                                    ? AppColors.error
                                    : product.isLowStock
                                        ? AppColors.warning
                                        : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Information section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                        boxShadow: AppShadows.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Информация',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _InfoRow(label: 'Артикул', value: product.sku ?? '—'),
                          const Divider(height: 20),
                          _InfoRow(label: 'Штрих-код', value: product.barcode ?? '—'),
                          const Divider(height: 20),
                          _InfoRow(label: 'Категория', value: product.categoryName ?? '—'),
                          const Divider(height: 20),
                          _InfoRow(label: 'Единица', value: unitName),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stock movements history
                    _StockMovementsSection(
                      storeId: () {
                        final storeState = context.read<StoreBloc>().state;
                        return storeState is StoreLoaded
                            ? storeState.selectedStore?.id ?? ''
                            : '';
                      }(),
                      productId: product.id,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            // 2 fixed bottom buttons: "Приход" + "Продать"
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: context.surface,
                boxShadow: AppShadows.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/stock/intake', extra: product),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Приход',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Add product to cart
                        context.read<CartBloc>().add(CartItemAdded(product: product));
                        // Show confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} добавлен в корзину'),
                            action: SnackBarAction(
                              label: 'В кассу',
                              onPressed: () => context.go('/home'),
                            ),
                          ),
                        );
                        // Navigate to home (POS tab is index 2)
                        context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: context.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                      label: const Text('Продать',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final storeState = context.read<StoreBloc>().state;
              final storeId = storeState is StoreLoaded
                  ? storeState.selectedStore?.id ?? ''
                  : '';
              context.read<ProductListBloc>().add(ProductDeleteRequested(
                storeId: storeId,
                productId: product.id,
              ));
              context.pop();
            },
            child: const Text('Удалить',
              style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _MiniMetricCard({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stock Movements History
// ---------------------------------------------------------------------------

class _StockMovementsSection extends StatefulWidget {
  final String storeId;
  final String productId;

  const _StockMovementsSection({
    required this.storeId,
    required this.productId,
  });

  @override
  State<_StockMovementsSection> createState() => _StockMovementsSectionState();
}

class _StockMovementsSectionState extends State<_StockMovementsSection> {
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    if (widget.storeId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Магазин не выбран';
      });
      return;
    }

    try {
      final resp = await sl<DioClient>().get<Map<String, dynamic>>(
        '/stores/${widget.storeId}/products/${widget.productId}/stock-movements',
        queryParameters: {'limit': 20},
      );
      final data = resp.data ?? {};
      final items = (data['data'] as List? ?? data['items'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _movements = items;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить историю движений';
      });
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'IN':
        return Icons.arrow_downward_rounded;
      case 'OUT':
        return Icons.arrow_upward_rounded;
      case 'ADJUSTMENT':
        return Icons.tune_rounded;
      default:
        return Icons.swap_vert_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'IN':
        return AppColors.success;
      case 'OUT':
        return AppColors.error;
      case 'ADJUSTMENT':
        return AppColors.warning;
      default:
        return context.textSecondary;
    }
  }

  String _typeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'IN':
        return 'Приход';
      case 'OUT':
        return 'Расход';
      case 'ADJUSTMENT':
        return 'Корректировка';
      default:
        return type;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('История движений',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 13)),
              ),
            )
          else if (_movements.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Нет движений',
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...List.generate(_movements.length, (i) {
              final m = _movements[i];
              final type = m['type'] as String? ?? '';
              final quantity = m['quantity'] as num? ?? 0;
              final note = m['note'] as String? ?? m['reason'] as String? ?? '';
              final date = m['createdAt'] as String? ?? m['date'] as String?;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _typeColor(type).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_typeIcon(type),
                              size: 16, color: _typeColor(type)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_typeLabel(type),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              if (note.isNotEmpty)
                                Text(note,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              if (date != null)
                                Text(_formatDate(date),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.textMuted)),
                            ],
                          ),
                        ),
                        Text(
                          '${type.toUpperCase() == 'OUT' ? '-' : '+'}$quantity',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _typeColor(type),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
