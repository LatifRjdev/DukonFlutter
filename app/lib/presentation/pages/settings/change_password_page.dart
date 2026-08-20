import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/settings/settings_event.dart';
import '../../blocs/settings/settings_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/app_text_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SettingsBloc>().add(SettingsPasswordChanged(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsActionSuccess) {
            AppSnackbar.success(context, state.message);
            context.pop();
          }
          if (state is SettingsError) {
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
                const Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
                const SizedBox(height: AppConstants.spacingLg),
                AppTextField(
                  controller: _currentPasswordController,
                  label: l10n.currentPassword,
                  obscureText: true,
                  prefixIcon: Icons.lock,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.currentPasswordRequired;
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _newPasswordController,
                  label: l10n.newPassword,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.newPasswordRequired;
                    if (v.length < 6) return l10n.passwordMinLength;
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _confirmPasswordController,
                  label: l10n.confirmPassword,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.confirmPassword;
                    if (v != _newPasswordController.text) return l10n.passwordsDoNotMatch;
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<SettingsBloc, SettingsState>(
                  builder: (context, state) {
                    return AppButton(
                      text: l10n.changePassword,
                      isLoading: state is SettingsLoading,
                      onPressed: _save,
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
