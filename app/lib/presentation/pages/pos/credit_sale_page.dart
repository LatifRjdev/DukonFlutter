import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_state.dart';
import '../../blocs/pos/checkout_bloc.dart';
import '../../blocs/pos/checkout_event.dart';
import '../../blocs/pos/checkout_state.dart';
import '../../blocs/customer/customer_list_bloc.dart';
import '../../blocs/customer/customer_list_event.dart';
import '../../blocs/customer/customer_list_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_snackbar.dart';

class CreditSalePage extends StatefulWidget {
  /// Optional clock for deterministic golden tests. Defaults to [DateTime.now].
  final DateTime Function()? now;

  const CreditSalePage({super.key, this.now});

  @override
  State<CreditSalePage> createState() => _CreditSalePageState();
}

class _CreditSalePageState extends State<CreditSalePage> {
  final _notesController = TextEditingController();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  late DateTime _dueDate;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _dueDate = _now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _now(),
      lastDate: _now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  void _selectCustomer() {
    final storeState = context.read<StoreBloc>().state;
    final storeId =
        storeState is StoreLoaded ? storeState.selectedStore?.id : null;
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
          builder: (sheetContext, scrollController) {
            final l10n = AppLocalizations.of(sheetContext)!;
            return Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.selectCustomer,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: BlocBuilder<CustomerListBloc, CustomerListState>(
                      builder: (context, state) {
                        if (state is CustomerListLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (state is CustomerListLoaded) {
                          if (state.customers.isEmpty) {
                            return Center(
                              child: Text(l10n.creditSaleCustomerListEmpty,
                                  style: TextStyle(color: sheetContext.textSecondary)),
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
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    customer.name.isNotEmpty
                                        ? customer.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                title: Text(customer.name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: customer.phone != null
                                    ? Text(customer.phone!,
                                        maxLines: 1, overflow: TextOverflow.ellipsis)
                                    : null,
                                onTap: () {
                                  this.context.read<CheckoutBloc>().add(
                                        CheckoutCustomerSelected(
                                          customerId: customer.id,
                                          customerName: customer.name,
                                        ),
                                      );
                                  setState(() {
                                    _selectedCustomerId = customer.id;
                                    _selectedCustomerName = customer.name;
                                  });
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
                  const SizedBox(height: 16),
                  AppButton(
                    text: l10n.creditSaleCreateCustomerButton,
                    icon: Icons.person_add_outlined,
                    type: AppButtonType.outlined,
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      _showCreateCustomerDialog(storeId);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateCustomerDialog(String storeId) {
    showDialog(
      context: context,
      builder: (ctx) => BlocListener<CustomerListBloc, CustomerListState>(
        listener: (listenerContext, state) {
          if (state is CustomerFormSuccess) {
            listenerContext.read<CheckoutBloc>().add(
                  CheckoutCustomerSelected(
                    customerId: state.customer.id,
                    customerName: state.customer.name,
                  ),
                );
            setState(() {
              _selectedCustomerId = state.customer.id;
              _selectedCustomerName = state.customer.name;
            });
            Navigator.pop(ctx);
          } else if (state is CustomerFormError) {
            AppSnackbar.error(listenerContext, state.message);
          }
        },
        child: _CreateCustomerDialogContent(storeId: storeId),
      ),
    );
  }

  void _confirm(double total) {
    if (_selectedCustomerId == null) return;

    final storeState = context.read<StoreBloc>().state;
    final storeId = storeState is StoreLoaded
        ? storeState.selectedStore?.id ?? ''
        : '';

    context.read<CheckoutBloc>()
      ..add(CheckoutPaymentMethodSelected('DEBT'))
      ..add(CheckoutPaidAmountChanged(0))
      ..add(CheckoutDebtDetailsChanged(
        dueDate: _dueDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ))
      ..add(CheckoutProcessPayment(storeId: storeId));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<CheckoutBloc, CheckoutState>(
      listener: (context, state) {
        if (state.saleResult != null) {
          context.go('/pos/success', extra: {
            'sale': state.saleResult,
          });
        }
        if (state.error != null) {
          AppSnackbar.error(context, state.error!);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.creditSaleTitle),
          leading: IconButton(
            tooltip: l10n.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocBuilder<CartBloc, CartState>(
          builder: (context, cart) {
            final total = cart.total;
            final isProcessing = context.watch<CheckoutBloc>().state.isProcessing;

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppConstants.spacingLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppCard(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            child: Column(
                              children: [
                                Text(l10n.debtAmount,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: context.textSecondary)),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.creditSaleAmountLabel(total.toStringAsFixed(2)),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(l10n.creditSaleCustomerRequiredLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AppCard(
                            onTap: _selectCustomer,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd),
                                  ),
                                  child: Icon(
                                    _selectedCustomerId != null
                                        ? Icons.person
                                        : Icons.person_add_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedCustomerName ?? l10n.selectCustomer,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: _selectedCustomerId != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: _selectedCustomerId != null
                                          ? context.textPrimary
                                          : context.textMuted,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: context.textSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(l10n.creditSaleDueDateLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AppCard(
                            onTap: _selectDueDate,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDate(_dueDate),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Icon(Icons.edit_outlined,
                                    size: 20, color: context.textSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(l10n.creditSaleNoteLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _notesController,
                            hint: l10n.creditSaleNoteHint,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingLg),
                    child: AppButton(
                      text: isProcessing ? l10n.processing : l10n.creditSaleConfirmButton,
                      icon: Icons.check,
                      onPressed: !isProcessing && _selectedCustomerId != null
                          ? () => _confirm(total)
                          : null,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Owns the name/phone controllers itself so their lifecycle is tied to this
/// widget's own State, independent of the surrounding BlocListener's
/// rebuild/pop timing (avoids "TextEditingController used after being
/// disposed" when the create-customer request resolves).
class _CreateCustomerDialogContent extends StatefulWidget {
  final String storeId;
  const _CreateCustomerDialogContent({required this.storeId});

  @override
  State<_CreateCustomerDialogContent> createState() =>
      _CreateCustomerDialogContentState();
}

class _CreateCustomerDialogContentState
    extends State<_CreateCustomerDialogContent> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSaving =
        context.watch<CustomerListBloc>().state is CustomerFormLoading;
    return AlertDialog(
      title: Text(l10n.newCustomer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _nameController,
            label: l10n.name,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _phoneController,
            label: l10n.phoneLabel,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: isSaving
              ? null
              : () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  final phone = _phoneController.text.trim();
                  context.read<CustomerListBloc>().add(
                        CustomerCreateRequested(
                          storeId: widget.storeId,
                          data: {
                            'name': name,
                            if (phone.isNotEmpty) 'phone': phone,
                          },
                        ),
                      );
                },
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.create),
        ),
      ],
    );
  }
}
