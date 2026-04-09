import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/product.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_event.dart';
import '../../blocs/pos/cart_state.dart';
import '../../blocs/pos/checkout_bloc.dart';
import '../../blocs/pos/checkout_event.dart';
import '../../blocs/pos/checkout_state.dart';
import '../../blocs/product/product_list_bloc.dart';
import '../../blocs/product/product_list_event.dart';
import '../../blocs/product/product_list_state.dart';
import '../../blocs/customer/customer_list_bloc.dart';
import '../../blocs/customer/customer_list_event.dart';
import '../../blocs/customer/customer_list_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class PosCheckoutPage extends StatefulWidget {
  const PosCheckoutPage({super.key});

  @override
  State<PosCheckoutPage> createState() => _PosCheckoutPageState();
}

class _PosCheckoutPageState extends State<PosCheckoutPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _showSearchResults = false;
  String? _storeId;
  String _selectedPaymentMethod = 'CASH';

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      _storeId = storeState.selectedStore!.id;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty && _storeId != null) {
      context.read<ProductListBloc>().add(ProductListSearchChanged(query));
    } else {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
    }
  }

  void _addProductToCart(Product product) {
    context.read<CartBloc>().add(CartItemAdded(product: product));
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
    });
  }

  void _initCheckoutAndProceed(CartState cart) {
    context.read<CheckoutBloc>().add(CheckoutInitiated(
      items: cart.items,
      subtotal: cart.subtotal,
      discount: cart.discountAmount,
      total: cart.total,
      customerId: cart.customerId,
      customerName: cart.customerName,
    ));
    context.read<CheckoutBloc>().add(CheckoutPaymentMethodSelected(_selectedPaymentMethod));

    switch (_selectedPaymentMethod) {
      case 'CASH':
        context.push('/pos/cash-payment');
        break;
      case 'CARD':
        final storeId = _storeId ?? '';
        context.read<CheckoutBloc>()
          ..add(CheckoutPaidAmountChanged(cart.total))
          ..add(CheckoutProcessPayment(storeId: storeId));
        break;
      case 'DEBT':
        context.push('/pos/credit-sale');
        break;
      case 'MIXED':
        context.push('/pos/cash-payment');
        break;
    }
  }

  void _showCustomerSelection() {
    final storeId = _storeId;
    if (storeId == null) return;

    context.read<CustomerListBloc>().add(CustomerListLoadRequested(storeId: storeId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Выберите клиента',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () {
                          this.context.read<CartBloc>().add(const CartCustomerSelected(customerId: null));
                          Navigator.pop(bottomSheetContext);
                        },
                        child: const Text('Без клиента'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: BlocBuilder<CustomerListBloc, CustomerListState>(
                    builder: (context, state) {
                      if (state is CustomerListLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is CustomerListLoaded) {
                        if (state.customers.isEmpty) {
                          return const Center(
                            child: Text('Нет клиентов', style: TextStyle(color: AppColors.textSecondary)),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: state.customers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final customer = state.customers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              title: Text(customer.name),
                              subtitle: customer.phone != null ? Text(customer.phone!) : null,
                              onTap: () {
                                this.context.read<CartBloc>().add(CartCustomerSelected(
                                  customerId: customer.id,
                                  customerName: customer.name,
                                ));
                                Navigator.pop(bottomSheetContext);
                              },
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeState = context.watch<StoreBloc>().state;
    final storeName = storeState is StoreLoaded && storeState.selectedStore != null
        ? storeState.selectedStore!.name
        : 'Магазин';

    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      _storeId = storeState.selectedStore!.id;
    }

    return BlocListener<CheckoutBloc, CheckoutState>(
      listener: (context, state) {
        if (state.saleResult != null) {
          context.go('/pos/success', extra: {'sale': state.saleResult});
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header: "Касса" + store name + person icon
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Касса',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text(storeName,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person_outline),
                      onPressed: _showCustomerSelection,
                    ),
                  ],
                ),
              ),

              // Search bar with big scanner icon
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Поиск по названию',
                            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Сканер штрихкодов скоро будет доступен')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Search results overlay
              BlocListener<ProductListBloc, ProductListState>(
                listener: (context, state) {
                  if (state is ProductListLoaded && _searchController.text.trim().isNotEmpty) {
                    setState(() {
                      _searchResults = state.products;
                      _showSearchResults = state.products.isNotEmpty;
                    });
                  }
                },
                child: _showSearchResults ? _buildSearchResults() : const SizedBox.shrink(),
              ),

              // Quick products horizontal scroll
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                child: SizedBox(
                  height: 72,
                  child: BlocBuilder<ProductListBloc, ProductListState>(
                    builder: (context, state) {
                      if (state is ProductListLoaded && state.products.isNotEmpty) {
                        final quickProducts = state.products.take(8).toList();
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: quickProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final p = quickProducts[index];
                            return GestureDetector(
                              onTap: () => _addProductToCart(p),
                              child: Container(
                                width: 80,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(p.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center),
                                    const SizedBox(height: 2),
                                    Text(p.sellPrice.toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      )),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

              // Cart content
              Expanded(
                child: BlocBuilder<CartBloc, CartState>(
                  builder: (context, cartState) {
                    if (cartState.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.disabled),
                            const SizedBox(height: 16),
                            const Text('Корзина пуста',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            const Text('Найдите товар или сканируйте штрихкод',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      );
                    }
                    return _buildCartContent(cartState);
                  },
                ),
              ),

              // Bottom: payment buttons + CTA
              BlocBuilder<CartBloc, CartState>(
                builder: (context, cartState) {
                  if (cartState.isEmpty) return const SizedBox.shrink();
                  return _buildBottomSection(cartState);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = _searchResults[index];
          return ListTile(
            dense: true,
            onTap: () => _addProductToCart(product),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: product.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.disabled)),
                    )
                  : const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.disabled),
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${product.quantity} шт', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: Text(_formatPrice(product.sellPrice),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
          );
        },
      ),
    );
  }

  Widget _buildCartContent(CartState cartState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart header
          Text('Корзина (${cartState.itemCount} товаров)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Cart items
          ...cartState.items.map((item) => _buildCartItem(item)),
          const SizedBox(height: 12),
          // Totals block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Подытог', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    Text(_formatPrice(cartState.subtotal),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Скидка', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showDiscountDialog(cartState),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ),
                      ],
                    ),
                    Text(cartState.discountAmount > 0
                        ? '-${_formatPrice(cartState.discountAmount)}'
                        : '0 TJS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cartState.discountAmount > 0 ? AppColors.error : AppColors.textSecondary,
                      )),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ИТОГО', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(_formatPrice(cartState.total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_formatPrice(item.unitPrice),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (item.quantity > 1) {
                        context.read<CartBloc>().add(CartItemQuantityChanged(
                          productId: item.productId, quantity: item.quantity - 1));
                      } else {
                        context.read<CartBloc>().add(CartItemRemoved(item.productId));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text('${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      context.read<CartBloc>().add(CartItemQuantityChanged(
                        productId: item.productId, quantity: item.quantity + 1));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(_formatPrice(item.total),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () {
                context.read<CartBloc>().add(CartItemRemoved(item.productId));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(CartState cartState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 4 payment method buttons
          Row(
            children: [
              _paymentMethodButton('CASH', 'Наличные', Icons.money),
              const SizedBox(width: 6),
              _paymentMethodButton('CARD', 'Карта', Icons.credit_card),
              const SizedBox(width: 6),
              _paymentMethodButton('DEBT', 'В долг', Icons.access_time),
              const SizedBox(width: 6),
              _paymentMethodButton('MIXED', 'Смешанная', Icons.compare_arrows),
            ],
          ),
          const SizedBox(height: 12),
          // CTA button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _initCheckoutAndProceed(cartState),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Оформить продажу — ${_formatPrice(cartState.total)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodButton(String method, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscountDialog(CartState cart) {
    final controller = TextEditingController(
      text: cart.discount > 0 ? cart.discount.toStringAsFixed(0) : '',
    );
    String discountType = cart.discountType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Скидка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => discountType = 'FIXED'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: discountType == 'FIXED'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: discountType == 'FIXED' ? AppColors.primary : AppColors.divider,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('TJS',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: discountType == 'FIXED' ? AppColors.primary : AppColors.textSecondary,
                          ))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => discountType = 'PERCENTAGE'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: discountType == 'PERCENTAGE'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: discountType == 'PERCENTAGE' ? AppColors.primary : AppColors.divider,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('%',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: discountType == 'PERCENTAGE' ? AppColors.primary : AppColors.textSecondary,
                          ))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: discountType == 'PERCENTAGE' ? 'Процент' : 'Сумма',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<CartBloc>().add(
                  const CartDiscountApplied(discount: 0, type: 'FIXED'));
                Navigator.pop(ctx);
              },
              child: const Text('Сбросить'),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text) ?? 0;
                context.read<CartBloc>().add(
                  CartDiscountApplied(discount: value, type: discountType));
                Navigator.pop(ctx);
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }
}
