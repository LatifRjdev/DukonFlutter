import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';

class BarcodeScannerSheet extends StatefulWidget {
  final ValueChanged<String> onScanned;

  const BarcodeScannerSheet({
    super.key,
    required this.onScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onScanned,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BarcodeScannerSheet(onScanned: onScanned),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    _scanned = true;
    Navigator.of(context).pop();
    widget.onScanned(value);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXxl),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Title row with close button
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingMd,
              right: AppConstants.spacingXs,
              top: AppConstants.spacingSm,
              bottom: AppConstants.spacingXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Сканер штрихкода',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.textSecondary,
                  ),
                  tooltip: 'Пӯшидан',
                ),
              ],
            ),
          ),

          Divider(height: 1, color: context.border),

          // Camera preview with overlay
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Scan frame overlay
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ),
              ],
            ),
          ),

          // Hint text
          Padding(
            padding: EdgeInsets.only(
              top: AppConstants.spacingMd,
              bottom: AppConstants.spacingMd +
                  MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Text(
              'Наведите камеру на штрихкод',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Inter',
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
