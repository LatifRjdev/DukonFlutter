import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/network_info.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../data/sync/sync_queue.dart';
import '../../../injection.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final NetworkInfo _networkInfo;
  late final SyncEngine _syncEngine;
  late final SyncQueue _syncQueue;

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<SyncStatus>? _syncStatusSub;

  bool _isOffline = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _networkInfo = sl<NetworkInfo>();
    _syncEngine = sl<SyncEngine>();
    _syncQueue = sl<SyncQueue>();

    _checkInitialState();

    _connectivitySub = _networkInfo.onConnectivityChanged.listen((connected) {
      setState(() => _isOffline = !connected);
      if (connected) _refreshPendingCount();
    });

    _syncStatusSub = _syncEngine.syncStatus.listen((status) {
      setState(() => _syncStatus = status);
      if (status == SyncStatus.completed || status == SyncStatus.error) {
        _refreshPendingCount();
      }
    });
  }

  Future<void> _checkInitialState() async {
    final connected = await _networkInfo.isConnected;
    final count = await _syncQueue.pendingCount();
    if (mounted) {
      setState(() {
        _isOffline = !connected;
        _pendingCount = count;
      });
    }
  }

  Future<void> _refreshPendingCount() async {
    final count = await _syncQueue.pendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _syncStatusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline && _syncStatus != SyncStatus.syncing && _pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final Color bgColor;
    final String message;
    final IconData icon;

    if (_isOffline) {
      bgColor = AppColors.warning;
      icon = Icons.cloud_off;
      message = _pendingCount > 0
          ? 'Офлайн режим · $_pendingCount в очереди'
          : 'Нет подключения к интернету';
    } else if (_syncStatus == SyncStatus.syncing) {
      bgColor = AppColors.info;
      icon = Icons.sync;
      message = 'Синхронизация...';
    } else if (_syncStatus == SyncStatus.error) {
      bgColor = AppColors.error;
      icon = Icons.sync_problem;
      message = 'Ошибка синхронизации · $_pendingCount не отправлено';
    } else if (_pendingCount > 0) {
      bgColor = AppColors.warning;
      icon = Icons.sync_problem;
      message = '$_pendingCount операций ожидают синхронизации';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          if (!_isOffline && _pendingCount > 0 && _syncStatus != SyncStatus.syncing) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _syncEngine.processQueue(),
              child: const Text(
                'Повторить',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
