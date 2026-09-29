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
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _dioClient = sl<DioClient>();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;

  bool _lowStock = true;
  bool _newSale = true;
  bool _shiftClosed = true;
  bool _deliveryCompleted = true;
  bool _debtReminder = true;
  int _daysWithoutSaleThreshold = 30;
  int _remainingPercentThreshold = 50;
  late final TextEditingController _daysController;
  late final TextEditingController _percentController;

  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController();
    _percentController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await _dioClient.get(
        '/stores/${widget.storeId}/notifications/settings',
      );
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _lowStock = data['lowStockAlerts'] as bool? ?? true;
        _newSale = data['newSaleAlerts'] as bool? ?? true;
        _shiftClosed = data['shiftClosedAlerts'] as bool? ?? true;
        _deliveryCompleted = data['deliveryCompletedAlerts'] as bool? ?? true;
        _debtReminder = data['debtReminderAlerts'] as bool? ?? true;
        _daysWithoutSaleThreshold =
            data['daysWithoutSaleThreshold'] as int? ?? 30;
        _remainingPercentThreshold =
            data['remainingPercentThreshold'] as int? ?? 50;
        _daysController.text = _daysWithoutSaleThreshold.toString();
        _percentController.text = _remainingPercentThreshold.toString();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        AppSnackbar.error(
          context,
          AppLocalizations.of(context)!.snackLoadError,
        );
      }
    }
  }

  String? _validateDaysThreshold(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return l10n.invalidFormatError;
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return l10n.invalidFormatError;
    if (parsed < 1) return l10n.invalidValue;
    return null;
  }

  String? _validatePercentThreshold(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return l10n.invalidFormatError;
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return l10n.invalidFormatError;
    if (parsed < 1 || parsed > 100) return l10n.percentRangeErrorFrom1;
    return null;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await _dioClient.put(
        '/stores/${widget.storeId}/notifications/settings',
        data: {
          'lowStockAlerts': _lowStock,
          'newSaleAlerts': _newSale,
          'shiftClosedAlerts': _shiftClosed,
          'deliveryCompletedAlerts': _deliveryCompleted,
          'debtReminderAlerts': _debtReminder,
          'daysWithoutSaleThreshold': int.parse(_daysController.text.trim()),
          'remainingPercentThreshold': int.parse(
            _percentController.text.trim(),
          ),
        },
      );
      if (mounted) {
        AppSnackbar.success(
          context,
          AppLocalizations.of(context)!.snackSettingsSaved,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          AppLocalizations.of(context)!.snackSaveError,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        title: Text(l10n.notificationSettingsPageTitle),
        backgroundColor: context.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                children: [
                  Text(
                    l10n.notificationSettingsSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  _buildSwitch(
                    l10n.notificationSettingsLowStockTitle,
                    l10n.notificationSettingsLowStockSubtitle,
                    Icons.inventory_2_outlined,
                    _lowStock,
                    (v) => setState(() => _lowStock = v),
                  ),
                  _buildSwitch(
                    l10n.newSale,
                    l10n.notificationSettingsNewSaleSubtitle,
                    Icons.shopping_cart_outlined,
                    _newSale,
                    (v) => setState(() => _newSale = v),
                  ),
                  _buildSwitch(
                    l10n.notificationSettingsShiftClosedTitle,
                    l10n.notificationSettingsShiftClosedSubtitle,
                    Icons.access_time_outlined,
                    _shiftClosed,
                    (v) => setState(() => _shiftClosed = v),
                  ),
                  _buildSwitch(
                    l10n.notificationSettingsDeliveryTitle,
                    l10n.notificationSettingsDeliverySubtitle,
                    Icons.local_shipping_outlined,
                    _deliveryCompleted,
                    (v) => setState(() => _deliveryCompleted = v),
                  ),
                  _buildSwitch(
                    l10n.notificationSettingsDebtReminderTitle,
                    l10n.notificationSettingsDebtReminderSubtitle,
                    Icons.warning_amber_outlined,
                    _debtReminder,
                    (v) => setState(() => _debtReminder = v),
                  ),
                  Card(
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.spacingSm,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                      side: BorderSide(color: context.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.notificationSettingsStaleProductTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.notificationSettingsStaleProductSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
                            validator: _validateDaysThreshold,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.notificationSettingsDaysWithoutSaleLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _percentController,
                            keyboardType: TextInputType.number,
                            validator: _validatePercentThreshold,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.notificationSettingsRemainingPercentLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: Builder(
                        builder: (ctx) => Text(
                          l10n.save,
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
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        secondary: Icon(
          icon,
          color: value ? AppColors.primary : context.textSecondary,
        ),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
