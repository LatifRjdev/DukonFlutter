import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/staff_member.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../blocs/staff/staff_event.dart';
import '../../blocs/staff_form/staff_form_bloc.dart';
import '../../blocs/staff_form/staff_form_event.dart';
import '../../blocs/staff_form/staff_form_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
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

  List<(String, String)> _roleOptions(AppLocalizations l10n) => [
        ('ADMIN', l10n.adminRoleShort),
        ('CASHIER', l10n.cashier),
        ('WAREHOUSE', l10n.warehouse),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editEmployee : l10n.addEmployee),
      ),
      body: BlocListener<StaffFormBloc, StaffFormState>(
        listener: (context, state) {
          if (state is StaffFormSuccess) {
            context.read<StaffBloc>().add(LoadStaff(storeId: widget.storeId));
            AppSnackbar.success(
              context,
              _isEditing ? l10n.employeeUpdated : l10n.employeeAdded,
            );
            context.pop();
          } else if (state is StaffFormError) {
            AppSnackbar.error(context, state.errorMessage ?? l10n.error);
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
                  label: l10n.staffFormNameLabel,
                  prefixIcon: Icons.person,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.enterName;
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _phoneController,
                  label: l10n.phoneLabel,
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Text(l10n.role, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: AppConstants.spacingSm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.border),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _role,
                      isExpanded: true,
                      items: _roleOptions(l10n).map((r) => DropdownMenuItem(
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
                  label: l10n.baseSalaryTjs,
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                      return l10n.invalidAmount;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _commissionController,
                  label: l10n.commissionPercentField,
                  prefixIcon: Icons.percent,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final val = double.tryParse(v);
                      if (val == null) return l10n.invalidValue;
                      if (val < 0 || val > 100) return l10n.percentRangeError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<StaffFormBloc, StaffFormState>(
                  builder: (context, state) {
                    return AppButton(
                      text: l10n.save,
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
