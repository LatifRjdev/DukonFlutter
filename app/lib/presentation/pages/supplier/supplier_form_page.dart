import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/supplier.dart';
import '../../blocs/supplier/supplier_list_bloc.dart';
import '../../blocs/supplier/supplier_list_event.dart';
import '../../blocs/supplier/supplier_list_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_snackbar.dart';

class SupplierFormPage extends StatefulWidget {
  final String storeId;
  final String? supplierId;
  final Supplier? existingSupplier;

  const SupplierFormPage({
    super.key,
    required this.storeId,
    this.supplierId,
    this.existingSupplier,
  });

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool get _isEditing => widget.supplierId != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSupplier;
    if (s != null) {
      _nameController.text = s.name;
      _phoneController.text = s.phone ?? '';
      _addressController.text = s.address ?? '';
      _notesController.text = s.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    if (_isEditing) {
      context.read<SupplierListBloc>().add(SupplierUpdateRequested(
        storeId: widget.storeId,
        supplierId: widget.supplierId!,
        data: data,
      ));
    } else {
      context.read<SupplierListBloc>().add(SupplierCreateRequested(
        storeId: widget.storeId,
        data: data,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editSupplier : l10n.newSupplier),
      ),
      body: BlocListener<SupplierListBloc, SupplierListState>(
        listener: (context, state) {
          if (state is SupplierFormSuccess) {
            AppSnackbar.success(context, _isEditing ? l10n.supplierUpdated : l10n.supplierAdded);
            // Pop with `true` so the caller (e.g. SupplierDetailPage) knows
            // to reload — SupplierDetailBloc is page-scoped, not app-wide
            // like CustomerDetailBloc, so it can't be reached from here.
            context.pop(true);
          } else if (state is SupplierFormError) {
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
                AppTextField(
                  controller: _nameController,
                  label: l10n.name,
                  prefixIcon: Icons.factory_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.enterName;
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _phoneController,
                  label: l10n.customerFormPhoneLabel,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final cleaned = v.trim();
                      if (!cleaned.startsWith('+992') && !cleaned.startsWith('992')) {
                        return l10n.customerFormPhoneCodeError;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _addressController,
                  label: l10n.address,
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _notesController,
                  label: l10n.notes,
                  prefixIcon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<SupplierListBloc, SupplierListState>(
                  builder: (context, state) {
                    return AppButton(
                      text: l10n.save,
                      isLoading: state is SupplierFormLoading,
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
