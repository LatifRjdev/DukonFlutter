import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/common/barcode_scanner_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../domain/entities/product.dart';
import '../../blocs/category/category_bloc.dart';
import '../../blocs/category/category_event.dart';
import '../../blocs/category/category_state.dart';
import '../../blocs/product/product_form_bloc.dart';
import '../../blocs/product/product_form_event.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import 'package:dokonpro/l10n/app_localizations.dart';

class AddProductStep1Page extends StatefulWidget {
  const AddProductStep1Page({super.key});

  @override
  State<AddProductStep1Page> createState() => _AddProductStep1PageState();
}

class _AddProductStep1PageState extends State<AddProductStep1Page> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryId;

  bool _isEditing = false;
  Product? _editingProduct;
  bool _initialized = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _checkForEditMode();
    }
  }

  void _checkForEditMode() {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      final product = extra['product'] as Product?;
      final isEditing = extra['isEditing'] as bool? ?? false;
      if (product != null && isEditing) {
        _isEditing = true;
        _editingProduct = product;
        _nameController.text = product.name;
        _skuController.text = product.sku ?? '';
        _barcodeController.text = product.barcode ?? '';
        _descriptionController.text = product.description ?? '';
        _selectedCategoryId = product.categoryId;
        setState(() {});
      }
    }
  }

  void _loadCategories() {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      context.read<CategoryBloc>().add(CategoryLoadRequested(storeState.selectedStore!.id));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _scanBarcode() {
    BarcodeScannerSheet.show(
      context,
      onScanned: (barcode) {
        _barcodeController.text = barcode;
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProductFormBloc>().add(ProductFormSaveStep(
        step: 0,
        data: {
          'name': _nameController.text,
          'sku': _skuController.text,
          'barcode': _barcodeController.text,
          'categoryId': _selectedCategoryId,
          'description': _descriptionController.text,
          if (_isEditing && _editingProduct != null) 'productId': _editingProduct!.id,
          'isEditing': _isEditing,
        },
      ));
      context.push('/products/add/step2');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать товар' : 'Новый товар'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg, vertical: AppConstants.spacingMd),
              child: Row(
                children: [
                  _StepDot(index: 1, label: 'Основное', isActive: true),
                  const Expanded(child: Divider()),
                  _StepDot(index: 2, label: 'Цены', isActive: false),
                  const Expanded(child: Divider()),
                  _StepDot(index: 3, label: 'Склад', isActive: false),
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
                      // Photo upload zone
                      Semantics(
                        label: l10n.a11yUploadPhoto,
                        button: true,
                        child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                            border: Border.all(
                              color: _selectedImage != null ? context.primary : context.border,
                              width: _selectedImage != null ? 2 : 1,
                            ),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusLg - 1),
                                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_a_photo_outlined,
                                        color: AppColors.primary, size: 28),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Добавить фото',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: context.textSecondary,
                                      )),
                                    const SizedBox(height: 4),
                                    Text('JPG, PNG до 5MB',
                                      style: TextStyle(fontSize: 12, color: context.textMuted)),
                                  ],
                                ),
                        ),
                      ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _nameController,
                        label: 'Название товара *',
                        prefixIcon: Icons.inventory_2_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Введите название';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _skuController,
                        label: 'Артикул (SKU)',
                        prefixIcon: Icons.tag,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _barcodeController,
                        label: 'Штрихкод',
                        prefixIcon: Icons.qr_code,
                        suffix: IconButton(
                          tooltip: l10n.scanBarcode,
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppColors.primary),
                          onPressed: _scanBarcode,
                        ),
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<CategoryBloc, CategoryState>(
                        builder: (context, state) {
                          final categories =
                              state is CategoryLoaded ? state.categories : [];
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedCategoryId,
                            decoration: InputDecoration(
                              labelText: 'Категория',
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusMd),
                              ),
                            ),
                            items: categories.map<DropdownMenuItem<String>>((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategoryId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Описание',
                        prefixIcon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: AppButton(
                text: 'Далее',
                icon: Icons.arrow_forward,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;

  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? context.primary : context.border,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: isActive ? Colors.white : context.textSecondary,
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
