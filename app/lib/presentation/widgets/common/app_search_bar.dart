import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onScanTap;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hint = 'Поиск...',
    this.onChanged,
    this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: onScanTap != null
            ? IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: onScanTap,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
