import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/dio_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sale.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../injection.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class SaleSuccessPage extends StatefulWidget {
  final Sale sale;

  const SaleSuccessPage({super.key, required this.sale});

  @override
  State<SaleSuccessPage> createState() => _SaleSuccessPageState();
}

class _SaleSuccessPageState extends State<SaleSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _printReceipt() async {
    final storeState = context.read<StoreBloc>().state;
    final storeName = storeState is StoreLoaded && storeState.selectedStore != null
        ? storeState.selectedStore!.name
        : 'DokonPro';

    final printerService = sl<ThermalPrinterService>();
    if (!printerService.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Принтер не подключён. Настройте в Настройки → Принтер.')),
      );
      return;
    }

    final success = await printerService.printReceipt(
      sale: widget.sale,
      storeName: storeName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Чек напечатан' : 'Ошибка печати'),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Green checkmark circle
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Продажа оформлена!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_formatPrice(sale.total),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              if (sale.change > 0) ...[
                const SizedBox(height: 8),
                Text('Сдача: ${_formatPrice(sale.change)}',
                  style: const TextStyle(fontSize: 16, color: AppColors.lightTextSecondary)),
              ],
              const Spacer(),

              // 3 buttons at bottom
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _printReceipt,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 20),
                  label: const Text('Печатать чек',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showShareOptions(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                  ),
                  icon: const Icon(Icons.send_outlined, size: 20),
                  label: const Text('Отправить в Telegram',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                  ),
                  child: const Text('Новая продажа',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    final sale = widget.sale;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.telegram, color: Colors.blue),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _sendTelegram(sale);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                Share.share('Чек #${sale.receiptNo}\nИтого: ${sale.total.toStringAsFixed(2)} сом.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('SMS'),
              onTap: () {
                Navigator.pop(context);
                Share.share('Чек #${sale.receiptNo}, Итого: ${sale.total.toStringAsFixed(2)} сом.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTelegram(Sale sale) async {
    try {
      final dio = sl<DioClient>();
      await dio.post('/stores/${sale.storeId}/telegram/send-receipt', data: {'saleId': sale.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Чек отправлен в Telegram'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить. Клиент не привязан к боту?'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
