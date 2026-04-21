import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../blocs/product/product_form_bloc.dart';
import '../../blocs/product/product_form_event.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class AddProductStep2Page extends StatefulWidget {
  const AddProductStep2Page({super.key});

  @override
  State<AddProductStep2Page> createState() => _AddProductStep2PageState();
}

class _AddProductStep2PageState extends State<AddProductStep2Page> {
  final _formKey = GlobalKey<FormState>();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  String _selectedUnit = 'PCS';

  static const _units = [
    {'value': 'PCS', 'label': 'Штука'},
    {'value': 'KG', 'label': 'Килограмм'},
    {'value': 'L', 'label': 'Литр'},
    {'value': 'M', 'label': 'Метр'},
    {'value': 'BOX', 'label': 'Коробка'},
    {'value': 'PACK', 'label': 'Упаковка'},
  ];

  @override
  void dispose() {
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _wholesalePriceController.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProductFormBloc>().add(ProductFormSaveStep(
        step: 1,
        data: {
          'costPrice': double.tryParse(_costPriceController.text) ?? 0,
          'sellPrice': double.tryParse(_sellPriceController.text) ?? 0,
          'wholesalePrice': double.tryParse(_wholesalePriceController.text) ?? 0,
          'unit': _selectedUnit,
        },
      ));
      context.push('/products/add/step3');
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
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg, vertical: AppConstants.spacingMd),
              child: Row(
                children: [
                  _StepDot(index: 1, label: 'Основное', isActive: false, isCompleted: true),
                  const Expanded(child: Divider()),
                  _StepDot(index: 2, label: 'Цены', isActive: true, isCompleted: false),
                  const Expanded(child: Divider()),
                  _StepDot(index: 3, label: 'Склад', isActive: false, isCompleted: false),
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
                        controller: _costPriceController,
                        label: 'Себестоимость *',
                        hint: '0.00',
                        prefixIcon: Icons.money_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Введите себестоимость';
                          if (double.tryParse(v) == null) return 'Неверный формат';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _sellPriceController,
                        label: 'Цена продажи *',
                        hint: '0.00',
                        prefixIcon: Icons.sell_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Введите цену продажи';
                          if (double.tryParse(v) == null) return 'Неверный формат';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _wholesalePriceController,
                        label: 'Оптовая цена',
                        hint: '0.00',
                        prefixIcon: Icons.price_change_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Единица измерения',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _units.map((u) {
                          final isSelected = _selectedUnit == u['value'];
                          return ChoiceChip(
                            label: Text(u['label']!),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? context.primary : context.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedUnit = u['value']!),
                          );
                        }).toList(),
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
                    child: AppButton(
                      text: 'Далее',
                      icon: Icons.arrow_forward,
                      onPressed: _next,
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
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
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
