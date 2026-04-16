import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/common/app_button.dart';

class OtpPage extends StatefulWidget {
  final String phone;

  const OtpPage({super.key, required this.phone});

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
    if (_otp.length == 6) {
      context.read<AuthBloc>().add(AuthVerifyOtpRequested(phone: widget.phone, code: _otp));
    }
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text('Подтверждение',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Введите 6-значный код, отправленный на\n${widget.phone}',
                  style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 16),
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
                      text: 'Подтвердить',
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
                          child: const Text('Отправить код повторно'),
                        )
                      : Text(
                          'Повторная отправка через $_remainingSeconds сек.',
                          style: const TextStyle(color: AppColors.lightTextSecondary),
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
