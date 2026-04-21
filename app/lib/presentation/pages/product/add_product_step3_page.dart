import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../blocs/product/product_form_bloc.dart';
import '../../blocs/product/product_form_event.dart';
import '../../blocs/product/product_form_state.dart';
import '../../blocs/product/product_list_bloc.dart';
import '../../blocs/product/product_list_event.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../blocs/supplier/supplier_list_bloc.dart';
import '../../blocs/supplier/supplier_list_event.dart';
import '../../blocs/supplier/supplier_list_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class AddProductStep3Page extends StatefulWidget {
  const AddProductStep3Page({super.key});

  @override
  State<AddProductStep3Page> createState() => _AddProductStep3PageState();
}

class _AddProductStep3PageState extends State<AddProductStep3Page> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _minQuantityController = TextEditingController();
  String? _selectedSupplierId;
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    final storeState = context.read<StoreBloc>().state;
    final storeId = storeState is StoreLoaded ? storeState.selectedStore?.id ?? '' : '';
    context.read<SupplierListBloc>().add(SupplierListLoadRequested(storeId: storeId));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _minQuantityController.dispose();
    super.dispose();
  }

  void _pickImage() {
    setState(() => _hasImage = true);
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      // Save step 2 data into the form bloc
      context.read<ProductFormBloc>().add(ProductFormSaveStep(
        step: 2,
        data: {
          'initialQuantity': int.tryParse(_quantityController.text) ?? 0,
          'minQuantity': int.tryParse(_minQuantityController.text) ?? 0,
          'supplierId': _selectedSupplierId,
        },
      ));

      final storeState = context.read<StoreBloc>().state;
      final storeId = storeState is StoreLoaded ? storeState.selectedStore?.id ?? '' : '';

      context.read<ProductFormBloc>().add(ProductFormSubmit(storeId: storeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый товар'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<ProductFormBloc, ProductFormState>(
        listener: (context, state) {
          if (state.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Товар сохранён. Синхронизация в фоне.'),
                backgroundColor: context.success,
              ),
            );
            context.read<ProductFormBloc>().add(ProductFormReset());
            // Trigger an explicit reload of the product list so the new
            // item appears immediately instead of leaving the user staring
            // at a stale cache with "1 операция в очереди" (FD-P1-003).
            final storeState = context.read<StoreBloc>().state;
            if (storeState is StoreLoaded &&
                storeState.selectedStore != null) {
              context.read<ProductListBloc>().add(
                    ProductListLoadRequested(
                      storeId: storeState.selectedStore!.id,
                    ),
                  );
            }
            context.go('/home');
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: context.danger,
              ),
            );
          }
        },
        child: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg, vertical: AppConstants.spacingMd),
              child: Row(
                children: [
                  _StepDot(index: 1, label: 'Основное', isCompleted: true),
                  const Expanded(child: Divider()),
                  _StepDot(index: 2, label: 'Цены', isCompleted: true),
                  const Expanded(child: Divider()),
                  _StepDot(index: 3, label: 'Склад', isActive: true),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _quantityController,
                        label: 'Начальное количество *',
                        hint: '0',
                        prefixIcon: Icons.inventory_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Введите количество';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _minQuantityController,
                        label: 'Минимальный остаток',
                        hint: '0',
                        prefixIcon: Icons.warning_amber_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<SupplierListBloc, SupplierListState>(
                        builder: (context, supplierState) {
                          final suppliers = supplierState is SupplierListLoaded
                              ? supplierState.suppliers
                              : [];
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedSupplierId,
                            decoration: InputDecoration(
                              labelText: 'Поставщик',
                              prefixIcon: const Icon(Icons.local_shipping_outlined),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusMd),
                              ),
                            ),
                            items: suppliers
                                .map((s) => DropdownMenuItem<String>(
                                      value: s.id,
                                      child: Text(s.name),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSupplierId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text('Фото товара',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Semantics(
                        label: 'Загрузить фото',
                        button: true,
                        child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            color: context.bg,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusLg),
                            border: Border.all(
                              color: context.border,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _hasImage
                              ? const Center(
                                  child: Icon(Icons.image,
                                      size: 64, color: AppColors.primary))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_outlined,
                                        size: 40, color: AppColors.disabled),
                                    const SizedBox(height: 8),
                                    Text('Нажмите для загрузки',
                                        style: TextStyle(
                                            color: context.textSecondary)),
                                  ],
                                ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Назад',
                      type: AppButtonType.outlined,
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BlocBuilder<ProductFormBloc, ProductFormState>(
                      builder: (context, state) {
                        return AppButton(
                          text: 'Добавить товар',
                          icon: Icons.check,
                          onPressed: _submit,
                          isLoading: state.isSubmitting,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepDot({
    required this.index,
    required this.label,
    this.isActive = false,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? context.primary
        : isCompleted
            ? context.success
            : context.border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 18, color: context.onSuccess)
                : Text(
                    '$index',
                    style: TextStyle(
                      color: isActive ? context.onPrimary : context.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? context.primary : context.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
