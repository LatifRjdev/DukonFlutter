import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/customer.dart';
import '../../../injection.dart';
import '../../blocs/customer/customer_list_bloc.dart';
import '../../blocs/customer/customer_list_event.dart';
import '../../blocs/customer/customer_list_state.dart';
import '../../blocs/customer_detail/customer_detail_bloc.dart';
import '../../blocs/customer_detail/customer_detail_event.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_snackbar.dart';

class CustomerFormPage extends StatefulWidget {
  final String storeId;
  final String? customerId;
  final Customer? existingCustomer;

  const CustomerFormPage({
    super.key,
    required this.storeId,
    this.customerId,
    this.existingCustomer,
  });

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _telegramController = TextEditingController();

  bool get _isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCustomer;
    if (c != null) {
      _nameController.text = c.name;
      _phoneController.text = c.phone ?? '';
      _notesController.text = c.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    if (_isEditing) {
      context.read<CustomerListBloc>().add(CustomerUpdateRequested(
        storeId: widget.storeId,
        customerId: widget.customerId!,
        data: data,
      ));
    } else {
      context.read<CustomerListBloc>().add(CustomerCreateRequested(
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
        title: Text(_isEditing ? l10n.editCustomer : l10n.newCustomer),
      ),
      body: BlocListener<CustomerListBloc, CustomerListState>(
        listener: (context, state) {
          if (state is CustomerFormSuccess) {
            final tg = _telegramController.text.trim();
            if (tg.isNotEmpty) {
              sl<DioClient>()
                  .put(
                    ApiEndpoints.customerTelegram(widget.storeId, state.customer.id),
                    data: {'username': tg},
                  )
                  .ignore();
            }
            // Reload customer detail if editing
            if (_isEditing) {
              context.read<CustomerDetailBloc>().add(
                CustomerDetailRequested(
                  storeId: widget.storeId,
                  customerId: widget.customerId!,
                ),
              );
            }
            AppSnackbar.success(context, _isEditing ? l10n.customerUpdated : l10n.customerAdded);
            context.pop();
          } else if (state is CustomerFormError) {
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
                  prefixIcon: Icons.person_outline,
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
                  controller: _notesController,
                  label: l10n.notes,
                  prefixIcon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _telegramController,
                  label: 'Telegram @username',
                  hint: '@alisher',
                  prefixIcon: Icons.telegram_outlined,
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<CustomerListBloc, CustomerListState>(
                  builder: (context, state) {
                    return AppButton(
                      text: l10n.save,
                      isLoading: state is CustomerFormLoading,
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
