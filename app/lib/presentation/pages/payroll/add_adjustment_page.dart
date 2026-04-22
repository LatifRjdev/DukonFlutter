import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_event.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/app_text_field.dart';

class AddAdjustmentPage extends StatefulWidget {
  final String storeId;
  final String periodId;
  const AddAdjustmentPage({super.key, required this.storeId, required this.periodId});
  @override
  State<AddAdjustmentPage> createState() => _AddAdjustmentPageState();
}

class _AddAdjustmentPageState extends State<AddAdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _staffIdController = TextEditingController();
  String _type = 'BONUS';

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _staffIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final data = <String, dynamic>{
      'type': _type,
      'amount': amount,
      'description': _descriptionController.text.trim(),
    };

    if (_staffIdController.text.trim().isNotEmpty) {
      data['staffId'] = _staffIdController.text.trim();
    }

    context.read<PayrollBloc>().add(AddAdjustment(
      storeId: widget.storeId,
      periodId: widget.periodId,
      data: data,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корректировка')),
      body: BlocListener<PayrollBloc, PayrollState>(
        listener: (context, state) {
          if (state is PayrollPeriodDetailLoaded) {
            AppSnackbar.success(context, 'Корректировка добавлена');
            context.pop();
          }
          if (state is PayrollError) {
            AppSnackbar.error(context, state.message);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      const Text(
                        'Добавить корректировку',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: AppConstants.spacingSm),
                      Text(
                        'Укажите тип, сумму и описание корректировки',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                const Text(
                  'Тип корректировки',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: _TypeToggle(
                        label: 'Бонус',
                        icon: Icons.add_circle_outline,
                        color: AppColors.success,
                        isSelected: _type == 'BONUS',
                        onTap: () => setState(() => _type = 'BONUS'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      child: _TypeToggle(
                        label: 'Удержание',
                        icon: Icons.remove_circle_outline,
                        color: AppColors.error,
                        isSelected: _type == 'DEDUCTION',
                        onTap: () => setState(() => _type = 'DEDUCTION'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AppTextField(
                  controller: _staffIdController,
                  label: 'ID сотрудника (необязательно)',
                  prefixIcon: Icons.person_outline,
                  hint: 'Оставьте пустым для всех',
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _amountController,
                  label: 'Сумма (TJS)',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите сумму';
                    if (double.tryParse(v) == null) return 'Некорректная сумма';
                    if (double.parse(v) <= 0) return 'Сумма должна быть больше 0';
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Описание',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите описание';
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<PayrollBloc, PayrollState>(
                  builder: (context, state) {
                    return AppButton(
                      text: 'Добавить',
                      icon: Icons.check,
                      isLoading: state is PayrollLoading,
                      onPressed: _submit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animationFast,
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingMd,
          horizontal: AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : context.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: isSelected ? color : context.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.disabled, size: 28),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : context.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
