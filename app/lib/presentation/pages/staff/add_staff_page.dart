import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/staff_member.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../blocs/staff/staff_event.dart';
import '../../blocs/staff_form/staff_form_bloc.dart';
import '../../blocs/staff_form/staff_form_event.dart';
import '../../blocs/staff_form/staff_form_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class AddStaffPage extends StatefulWidget {
  final String storeId;
  final StaffMember? staffMember;

  const AddStaffPage({super.key, required this.storeId, this.staffMember});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController();
  final _commissionController = TextEditingController();
  String _role = 'CASHIER';

  bool get _isEditing => widget.staffMember != null;

  final _roleOptions = [
    ('ADMIN', 'Админ'),
    ('CASHIER', 'Кассир'),
    ('WAREHOUSE', 'Складовщик'),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      context.read<StaffFormBloc>().add(InitStaffForm(staffMember: widget.staffMember));
      final s = widget.staffMember!;
      _nameController.text = s.name;
      _phoneController.text = s.phone ?? '';
      _salaryController.text = s.salary?.toStringAsFixed(0) ?? '';
      _commissionController.text = s.commission?.toStringAsFixed(1) ?? '';
      _role = s.role;
    } else {
      context.read<StaffFormBloc>().add(const InitStaffForm());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'role': _role,
      'salary': double.tryParse(_salaryController.text),
      'commission': double.tryParse(_commissionController.text),
    };

    context.read<StaffFormBloc>().add(SubmitStaffForm(
      storeId: widget.storeId,
      data: data,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать сотрудника' : 'Добавить сотрудника'),
      ),
      body: BlocListener<StaffFormBloc, StaffFormState>(
        listener: (context, state) {
          if (state is StaffFormSuccess) {
            context.read<StaffBloc>().add(LoadStaff(storeId: widget.storeId));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing ? 'Сотрудник обновлён' : 'Сотрудник добавлен'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          } else if (state is StaffFormError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? 'Ошибка'), backgroundColor: AppColors.error),
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
                  label: 'Имя сотрудника',
                  prefixIcon: Icons.person,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите имя';
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _phoneController,
                  label: 'Телефон',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                const Text('Роль', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: AppConstants.spacingSm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _role,
                      isExpanded: true,
                      items: _roleOptions.map((r) => DropdownMenuItem(
                        value: r.$1,
                        child: Text(r.$2),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _role = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _salaryController,
                  label: 'Оклад (TJS)',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                      return 'Некорректная сумма';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _commissionController,
                  label: 'Комиссия (%)',
                  prefixIcon: Icons.percent,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final val = double.tryParse(v);
                      if (val == null) return 'Некорректное значение';
                      if (val < 0 || val > 100) return 'От 0 до 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<StaffFormBloc, StaffFormState>(
                  builder: (context, state) {
                    return AppButton(
                      text: 'Сохранить',
                      isLoading: state is StaffFormLoading,
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
