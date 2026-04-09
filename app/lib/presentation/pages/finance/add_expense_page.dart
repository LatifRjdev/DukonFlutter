import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/expense/expense_bloc.dart';
import '../../blocs/expense/expense_event.dart';
import '../../blocs/expense/expense_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class AddExpensePage extends StatefulWidget {
  final String storeId;
  const AddExpensePage({super.key, required this.storeId});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = 'OTHER';
  DateTime _date = DateTime.now();

  final _categoryOptions = [
    ('PURCHASE', 'Закупка'),
    ('RENT', 'Аренда'),
    ('SALARY', 'Зарплата'),
    ('UTILITIES', 'Коммунальные'),
    ('TRANSPORT', 'Транспорт'),
    ('MARKETING', 'Маркетинг'),
    ('OTHER', 'Другое'),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    context.read<ExpenseBloc>().add(ExpenseCreateRequested(
      storeId: widget.storeId,
      data: {
        'category': _category,
        'amount': amount,
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'date': _date.toIso8601String(),
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить расход')),
      body: BlocListener<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state is ExpenseActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
            );
            context.pop();
          }
          if (state is ExpenseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Категория', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: AppConstants.spacingSm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category,
                      isExpanded: true,
                      items: _categoryOptions.map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(c.$2),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _amountController,
                  label: 'Сумма',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.attach_money,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите сумму';
                    if (double.tryParse(v) == null) return 'Некорректная сумма';
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Описание',
                  prefixIcon: Icons.description,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _notesController,
                  label: 'Заметки',
                  maxLines: 3,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightBorder),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.lightTextSecondary, size: 20),
                        const SizedBox(width: AppConstants.spacingSm),
                        Text(
                          '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<ExpenseBloc, ExpenseState>(
                  builder: (context, state) {
                    return AppButton(
                      text: 'Сохранить',
                      isLoading: state is ExpenseLoading,
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
