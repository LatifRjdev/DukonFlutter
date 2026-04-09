import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    // Auto-focus the first field after the frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode =>
      _controllers.map((c) => c.text).join();

  void _notifyChange() {
    final code = _currentCode;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  void _handlePaste(String pasted) {
    final digits = pasted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    for (var i = 0; i < widget.length && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }

    final focusIndex =
        digits.length >= widget.length ? widget.length - 1 : digits.length;
    _focusNodes[focusIndex].requestFocus();
    _notifyChange();
  }

  void _onFieldChanged(int index, String value) {
    // Handle paste of multiple characters into a single field.
    if (value.length > 1) {
      _handlePaste(value);
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _notifyChange();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        _notifyChange();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: index == 0 || index == widget.length - 1 ? 0 : 4,
          ).copyWith(
            left: index == 0 ? 0 : 4,
            right: index == widget.length - 1 ? 0 : 4,
          ),
          child: SizedBox(
            width: 48,
            height: 56,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) => _onKey(index, event),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: AppColors.lightTextPrimary,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.lightSurface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.buttonRadius),
                    borderSide: const BorderSide(
                      color: AppColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.buttonRadius),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.buttonRadius),
                    borderSide: const BorderSide(
                      color: AppColors.error,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.buttonRadius),
                    borderSide: const BorderSide(
                      color: AppColors.error,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => _onFieldChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}
