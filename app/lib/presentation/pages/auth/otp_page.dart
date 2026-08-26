import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';

class OtpPage extends StatefulWidget {
  /// Default purpose — OTP confirmation logs the user in (existing
  /// behavior for OTP-based login).
  static const String purposeLogin = 'login';

  /// Forgot-password flow — OTP confirmation must NOT log the user into
  /// their old account. It only proves the code is valid client-side
  /// enough to proceed to [CreatePasswordPage], which performs the real
  /// server-side validation via `resetPassword(phone, code, newPassword)`.
  static const String purposePasswordReset = 'passwordReset';

  final String phone;
  final String purpose;

  const OtpPage({
    super.key,
    required this.phone,
    this.purpose = purposeLogin,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _verify() {
    if (_otp.length != 6) return;

    if (widget.purpose == OtpPage.purposePasswordReset) {
      // Don't dispatch AuthVerifyOtpRequested here — that event logs the
      // user in (persists tokens for whatever account owns `phone`), which
      // is exactly the bug this purpose exists to avoid. Client-side we
      // only know the code is 6 digits; the real validation happens when
      // CreatePasswordPage submits AuthResetPasswordRequested, which passes
      // this same code to resetPassword(phone, code, newPassword).
      context.push('/create-password', extra: {
        'phone': widget.phone,
        'otp': _otp,
      });
      return;
    }

    context.read<AuthBloc>().add(AuthVerifyOtpRequested(phone: widget.phone, code: _otp));
  }

  void _resend() {
    if (_canResend) {
      context.read<AuthBloc>().add(AuthSendOtpRequested(phone: widget.phone));
      _startTimer();
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) {
      _verify();
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
          if (state is AuthAuthenticated) {
            context.go('/home');
          } else if (state is AuthFailure) {
            AppSnackbar.error(context, state.message);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(l10n.otpPageTitle,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  l10n.otpInstructions(widget.phone),
                  style: TextStyle(color: context.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMd),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMd),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return AppButton(
                      text: l10n.confirm,
                      onPressed: _otp.length == 6 ? _verify : null,
                      isLoading: state is AuthLoading,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: _canResend
                      ? TextButton(
                          onPressed: _resend,
                          child: Text(l10n.otpResendButton),
                        )
                      : Text(
                          l10n.otpResendCountdown('$_remainingSeconds'),
                          style: TextStyle(color: context.textSecondary),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
