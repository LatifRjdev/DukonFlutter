import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class OfflineModePage extends StatefulWidget {
  const OfflineModePage({super.key});

  @override
  State<OfflineModePage> createState() => _OfflineModePageState();
}

class _OfflineModePageState extends State<OfflineModePage> {
  final _dioClient = sl<DioClient>();
  static const _keyAutoSync = 'offline_auto_sync';

  bool _autoSync = true;
  DateTime? _lastSync;
  int _pendingOps = 0;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _autoSync = prefs.getBool(_keyAutoSync) ?? true;

    final lastSyncMs = prefs.getInt('last_sync_timestamp');
    if (lastSyncMs != null) {
      _lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }

    try {
      final res = await _dioClient.get('/sync/status');
      final data = res.data as Map<String, dynamic>? ?? {};
      _pendingOps = data['pendingOperations'] as int? ?? 0;
    } catch (_) {
      _pendingOps = 0;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _manualSync() async {
    setState(() => _syncing = true);
    try {
      await _dioClient.post('/sync/trigger');
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt('last_sync_timestamp', now.millisecondsSinceEpoch);
      if (mounted) {
        setState(() {
          _lastSync = now;
          _pendingOps = 0;
          _syncing = false;
        });
        AppSnackbar.success(context, AppLocalizations.of(context)!.snackSyncCompleted);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncing = false);
        AppSnackbar.error(context, AppLocalizations.of(context)!.snackSyncError(mapErrorToUserMessage(e)));
      }
    }
  }

  Future<void> _saveAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, value);
    if (mounted) setState(() => _autoSync = value);
  }

  void _confirmClearCache() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.offlineResetSyncStatusTitle),
        content: Text(l10n.offlineResetSyncStatusBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache();
            },
            child: Text(l10n.offlineResetSyncStatusConfirm,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // This does NOT wipe any local SQLite tables (products/categories/sales,
  // etc.) — those double as the offline-first read source and can hold
  // local writes not yet confirmed by the server (e.g. an offline sale or
  // product created while disconnected), so clearing them here would risk
  // real data loss or breaking offline reads. All this does — and all its
  // label promises — is discard the locally displayed "last synced at"
  // timestamp and reset the in-memory pending-ops count, so the sync
  // status card goes back to "not synced yet" until the next real sync.
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_timestamp');
      if (mounted) {
        setState(() { _lastSync = null; _pendingOps = 0; });
        AppSnackbar.success(context, AppLocalizations.of(context)!.snackSyncStatusReset);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, mapErrorToUserMessage(e));
      }
    }
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Офлайн-режим'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sync status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _pendingOps == 0
                          ? AppColors.success.withValues(alpha: 0.08)
                          : context.warningBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                      border: Border.all(
                        color: _pendingOps == 0
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _pendingOps == 0
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_upload_outlined,
                              color: _pendingOps == 0
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _pendingOps == 0
                                  ? 'Всё синхронизировано'
                                  : '$_pendingOps операций в очереди',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _pendingOps == 0
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        if (_lastSync != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Последняя синхронизация: ${_formatDate(_lastSync!)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Синхронизация ещё не выполнялась',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Manual sync button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLg)),
                      ),
                      onPressed: _syncing ? null : _manualSync,
                      icon: _syncing
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync),
                      label: Text(
                        _syncing ? 'Синхронизация...' : 'Синхронизировать сейчас',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Settings
                  Text('Настройки',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: const Icon(Icons.sync_outlined,
                                color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Авто-синхронизация',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text('Синхронизировать при подключении к сети',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoSync,
                            onChanged: _saveAutoSync,
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.infoBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'В офлайн-режиме все операции сохраняются локально '
                            'и автоматически синхронизируются при восстановлении '
                            'подключения к интернету.',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clear cache
                  Text('Данные',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLg)),
                      ),
                      onPressed: _confirmClearCache,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(
                          AppLocalizations.of(context)!.offlineResetSyncStatusButton,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
