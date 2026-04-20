import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/phone_input_field.dart';

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
            context.push('/otp', extra: state.phone);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
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
                  const Text('Забыли пароль?',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Введите номер телефона, привязанный к вашему аккаунту. Мы отправим код подтверждения.',
                    style: TextStyle(color: context.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  PhoneInputField(
                    controller: _phoneController,
                    validator: (v) {
                      if (v == null || v.length < 9) return 'Введите номер телефона';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return AppButton(
                        text: 'Отправить код',
                        onPressed: _submit,
                        isLoading: state is AuthLoading,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Вернуться к входу'),
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
