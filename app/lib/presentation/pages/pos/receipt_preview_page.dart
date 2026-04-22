import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/receipt_share_service.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../domain/entities/sale.dart';
import '../../../injection.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/pos/receipt_widget.dart';

class ReceiptPreviewPage extends StatelessWidget {
  final Sale sale;

  const ReceiptPreviewPage({super.key, required this.sale});

  Future<void> _shareReceipt(BuildContext context) async {
    final storeState = context.read<StoreBloc>().state;
    final storeName = storeState is StoreLoaded && storeState.selectedStore != null
        ? storeState.selectedStore!.name
        : 'DukonPro';
    try {
      await sl<ReceiptShareService>().shareReceipt(
        sale: sale,
        storeName: storeName,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.error(context, 'Ошибка: ${e.toString()}');
    }
  }

  Future<void> _printReceipt(BuildContext context) async {
    final storeState = context.read<StoreBloc>().state;
    final storeName = storeState is StoreLoaded && storeState.selectedStore != null
        ? storeState.selectedStore!.name
        : 'DukonPro';
    final printerService = sl<ThermalPrinterService>();
    if (!printerService.isConnected) {
      AppSnackbar.error(context, 'Принтер не подключён. Настройте в Настройки → Принтер.');
      return;
    }

    final success = await printerService.printReceipt(
      sale: sale,
      storeName: storeName,
    );

    if (!context.mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Чек напечатан');
    } else {
      AppSnackbar.error(context, 'Ошибка печати');
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeState = context.read<StoreBloc>().state;
    final storeName = storeState is StoreLoaded && storeState.selectedStore != null
        ? storeState.selectedStore!.name
        : 'DukonPro';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чек'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Поделиться',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareReceipt(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: ReceiptWidget(
                  sale: sale,
                  storeName: storeName,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Поделиться',
                      icon: Icons.share_outlined,
                      type: AppButtonType.outlined,
                      onPressed: () => _shareReceipt(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Печать',
                      icon: Icons.print_outlined,
                      onPressed: () => _printReceipt(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
