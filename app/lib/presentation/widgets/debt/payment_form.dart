import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../common/app_button.dart';
import '../common/app_text_field.dart';

class PaymentForm extends StatefulWidget {
  final double maxAmount;
  final ValueChanged<({double amount, String method, String? notes})> onSubmit;

  const PaymentForm({super.key, required this.maxAmount, required this.onSubmit});

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _method = 'CASH';

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Принять оплату', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppConstants.spacingMd),
        Text('Максимум: ${widget.maxAmount.toStringAsFixed(2)} TJS', style: TextStyle(color: context.textSecondary, fontSize: 13)),
        const SizedBox(height: AppConstants.spacingSm),
        AppTextField(
          controller: _amountController,
          label: 'Сумма',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.attach_money,
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Row(
          children: ['CASH', 'CARD'].map((m) {
            final isSelected = m == _method;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _method = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : context.surface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(color: isSelected ? AppColors.primary : context.textSecondary.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    m == 'CASH' ? 'Наличные' : 'Карта',
                    style: TextStyle(color: isSelected ? context.onPrimary : context.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        AppTextField(controller: _notesController, label: 'Заметки', maxLines: 2),
        const SizedBox(height: AppConstants.spacingLg),
        AppButton(
          text: 'Принять оплату',
          onPressed: () {
            final amount = double.tryParse(_amountController.text) ?? 0;
            if (amount <= 0 || amount > widget.maxAmount) return;
            widget.onSubmit((amount: amount, method: _method, notes: _notesController.text.isEmpty ? null : _notesController.text));
          },
        ),
      ],
    );
  }
}
