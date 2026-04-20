import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../injection.dart';
import '../../blocs/investment/investment_bloc.dart';
import '../../blocs/investment/investment_event.dart';
import '../../blocs/investment/investment_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class AddInvestmentPage extends StatefulWidget {
  final String storeId;
  const AddInvestmentPage({super.key, required this.storeId});
  @override
  State<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends State<AddInvestmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _returnAmountController = TextEditingController();
  final _investorNameController = TextEditingController();
  final _investorPhoneController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _returnAmountController.dispose();
    _investorNameController.dispose();
    _investorPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final returnAmount = double.tryParse(_returnAmountController.text);

    context.read<InvestmentBloc>().add(InvestmentCreateRequested(
      storeId: widget.storeId,
      data: {
        'name': _nameController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'amount': amount,
        'returnAmount': ?returnAmount,
        'investorName': _investorNameController.text,
        'investorPhone': _investorPhoneController.text.isEmpty
            ? null
            : _investorPhoneController.text,
        'startDate': _startDate.toIso8601String(),
        if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
      },
    ));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvestmentBloc>(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(title: const Text('Добавить вложение')),
            body: BlocListener<InvestmentBloc, InvestmentState>(
              listener: (context, state) {
                if (state is InvestmentActionSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message),
                        backgroundColor: context.success),
                  );
                  context.pop(true);
                }
                if (state is InvestmentError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message),
                        backgroundColor: context.danger),
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
                      AppTextField(
                        controller: _nameController,
                        label: 'Название',
                        prefixIcon: Icons.label_outline,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите название';
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
                        controller: _amountController,
                        label: 'Сумма',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.attach_money,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите сумму';
                          if (double.tryParse(v) == null) {
                            return 'Некорректная сумма';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      AppTextField(
                        controller: _returnAmountController,
                        label: 'Сумма возврата',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.money,
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      AppTextField(
                        controller: _investorNameController,
                        label: 'Имя инвестора',
                        prefixIcon: Icons.person_outline,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Введите имя инвестора';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      AppTextField(
                        controller: _investorPhoneController,
                        label: 'Телефон инвестора',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      const Text('Дата начала',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: AppConstants.spacingSm),
                      GestureDetector(
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.border),
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: context.textSecondary,
                                  size: 20),
                              const SizedBox(width: AppConstants.spacingSm),
                              Text(_formatDate(_startDate),
                                  style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      const Text('Дата окончания (необязательно)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: AppConstants.spacingSm),
                      GestureDetector(
                        onTap: _pickEndDate,
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.border),
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: context.textSecondary,
                                  size: 20),
                              const SizedBox(width: AppConstants.spacingSm),
                              Text(
                                _endDate != null
                                    ? _formatDate(_endDate!)
                                    : 'Не выбрана',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: _endDate != null
                                        ? null
                                        : context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXl),
                      BlocBuilder<InvestmentBloc, InvestmentState>(
                        builder: (context, state) {
                          return AppButton(
                            text: 'Сохранить',
                            isLoading: state is InvestmentLoading,
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
        },
      ),
    );
  }
}
