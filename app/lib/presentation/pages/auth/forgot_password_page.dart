import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/phone_input_field.dart';
import 'otp_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final phone = '+992${_phoneController.text}';
      context.read<AuthBloc>().add(AuthForgotPasswordRequested(phone: phone));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthOtpSent) {
            // purpose: passwordReset tells OtpPage to route to
            // CreatePasswordPage after the code is confirmed, instead of
            // logging the user into their old account (SPEC.md #3).
            context.push('/otp', extra: {
              'phone': state.phone,
              'purpose': OtpPage.purposePasswordReset,
            });
          } else if (state is AuthFailure) {
            AppSnackbar.error(context, state.message);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(l10n.forgotPassword,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.forgotPasswordSubtitle,
                    style: TextStyle(color: context.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  PhoneInputField(
                    controller: _phoneController,
                    validator: (v) {
                      if (v == null || v.length < 9) return l10n.phoneRequired;
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return AppButton(
                        text: l10n.forgotPasswordSendCodeButton,
                        onPressed: _submit,
                        isLoading: state is AuthLoading,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text(l10n.forgotPasswordBackToLogin),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
