import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_shadows.dart';

class AppSearchBar extends StatefulWidget {
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
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    // TextField.onChanged only fires on user input, not programmatic
    // changes — controller.clear() alone won't notify callers, so fire
    // it manually.
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showClear = widget.onScanTap == null && _controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: isDark ? null : AppShadows.sm,
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          suffixIcon: widget.onScanTap != null
              ? IconButton(
                  icon: Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary),
                  onPressed: widget.onScanTap,
                )
              : (showClear
                  ? IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      onPressed: _clear,
                    )
                  : null),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
