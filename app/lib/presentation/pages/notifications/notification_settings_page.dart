import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class NotificationSettingsPage extends StatefulWidget {
  final String storeId;
  const NotificationSettingsPage({super.key, required this.storeId});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;

  bool _lowStock = true;
  bool _newSale = true;
  bool _shiftClosed = true;
  bool _deliveryCompleted = true;
  bool _debtReminder = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await _dioClient.get('/stores/${widget.storeId}/notifications/settings');
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _lowStock = data['lowStock'] as bool? ?? true;
        _newSale = data['newSale'] as bool? ?? true;
        _shiftClosed = data['shiftClosed'] as bool? ?? true;
        _deliveryCompleted = data['deliveryCompleted'] as bool? ?? true;
        _debtReminder = data['debtReminder'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _dioClient.put('/stores/${widget.storeId}/notifications/settings', data: {
        'lowStock': _lowStock,
        'newSale': _newSale,
        'shiftClosed': _shiftClosed,
        'deliveryCompleted': _deliveryCompleted,
        'debtReminder': _debtReminder,
      });
      if (mounted) {
        AppSnackbar.success(context, AppLocalizations.of(context)!.snackSettingsSaved);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, AppLocalizations.of(context)!.snackSaveError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
        backgroundColor: context.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              children: [
                Text(
                  'Выберите какие уведомления вы хотите получать',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                _buildSwitch(
                  'Низкий остаток',
                  'Когда товар заканчивается на складе',
                  Icons.inventory_2_outlined,
                  _lowStock,
                  (v) => setState(() => _lowStock = v),
                ),
                _buildSwitch(
                  'Новая продажа',
                  'Когда кассир оформляет продажу',
                  Icons.shopping_cart_outlined,
                  _newSale,
                  (v) => setState(() => _newSale = v),
                ),
                _buildSwitch(
                  'Закрытие смены',
                  'Когда смена закрывается',
                  Icons.access_time_outlined,
                  _shiftClosed,
                  (v) => setState(() => _shiftClosed = v),
                ),
                _buildSwitch(
                  'Доставка выполнена',
                  'Когда курьер доставил заказ',
                  Icons.local_shipping_outlined,
                  _deliveryCompleted,
                  (v) => setState(() => _deliveryCompleted = v),
                ),
                _buildSwitch(
                  'Напоминание о долге',
                  'Просроченные долги клиентов (> 7 дней)',
                  Icons.warning_amber_outlined,
                  _debtReminder,
                  (v) => setState(() => _debtReminder = v),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                    ),
                    child: Builder(
                      builder: (ctx) => Text(
                        'Сохранить',
                        style: TextStyle(
                          color: ctx.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: context.border),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
        secondary: Icon(icon, color: value ? AppColors.primary : context.textSecondary),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
