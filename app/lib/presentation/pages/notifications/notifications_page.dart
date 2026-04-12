import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../../injection.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum _NotifType { bell, warning, cart, truck }

class _AppNotification {
  final String id;
  final _NotifType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const _AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory _AppNotification.fromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? 'bell';
    _NotifType type;
    switch (typeStr) {
      case 'low_stock':
        type = _NotifType.warning;
        break;
      case 'new_sale':
        type = _NotifType.cart;
        break;
      case 'delivery':
        type = _NotifType.truck;
        break;
      default:
        type = _NotifType.bell;
    }
    return _AppNotification(
      id: j['id'] as String? ?? '',
      type: type,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: j['isRead'] as bool? ?? false,
    );
  }

  _AppNotification copyWithRead() => _AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: true,
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class NotificationsPage extends StatefulWidget {
  final String storeId;
  const NotificationsPage({super.key, required this.storeId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  String get _storeId {
    if (widget.storeId.isNotEmpty) return widget.storeId;
    final s = context.read<StoreBloc>().state;
    return s is StoreLoaded ? (s.selectedStore?.id ?? '') : '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final id = _storeId;
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Магазин не выбран';
      });
      return;
    }

    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _notifications.clear();
      });
    }

    try {
      final resp = await sl<DioClient>().get<Map<String, dynamic>>(
        '/stores/$id/notifications',
        queryParameters: {'page': _page, 'limit': 20},
      );
      final data = resp.data ?? {};
      final items = (data['data'] as List? ?? data['items'] as List? ?? [])
          .map((e) => _AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = data['total'] as int? ?? items.length;

      setState(() {
        _loading = false;
        _notifications.addAll(items);
        _hasMore = _notifications.length < total;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить уведомления';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _page++;
    });
    await _load();
    setState(() => _loadingMore = false);
  }

  Future<void> _markRead(int index) async {
    final notif = _notifications[index];
    if (notif.isRead) return;

    final id = _storeId;
    try {
      await sl<DioClient>().put<void>('/stores/$id/notifications/${notif.id}/read');
      setState(() {
        _notifications[index] = notif.copyWithRead();
      });
    } catch (_) {
      // Optimistically update anyway
      setState(() {
        _notifications[index] = notif.copyWithRead();
      });
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} д назад';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  IconData _typeIcon(_NotifType type) {
    switch (type) {
      case _NotifType.warning:
        return Icons.warning_amber_rounded;
      case _NotifType.cart:
        return Icons.shopping_cart_outlined;
      case _NotifType.truck:
        return Icons.local_shipping_outlined;
      case _NotifType.bell:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(_NotifType type) {
    switch (type) {
      case _NotifType.warning:
        return AppColors.warning;
      case _NotifType.cart:
        return AppColors.primary;
      case _NotifType.truck:
        return AppColors.info;
      case _NotifType.bell:
        return AppColors.lightTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Уведомления',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
            onPressed: () => context.push(
              '/notifications/settings',
              extra: _storeId,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => _load(refresh: true),
                  child: _notifications.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingSm),
                          itemCount:
                              _notifications.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, i) {
                            if (i >= _notifications.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            }
                            final n = _notifications[i];
                            return _NotificationCard(
                              notification: n,
                              icon: _typeIcon(n.type),
                              iconColor: _typeColor(n.type),
                              timeAgo: _timeAgo(n.createdAt),
                              onTap: () => _markRead(i),
                            );
                          },
                        ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.lightTextSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _load(refresh: true),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: AppColors.lightTextHint),
          SizedBox(height: 12),
          Text('Нет уведомлений',
              style: TextStyle(
                  fontSize: 16,
                  color: AppColors.lightTextSecondary,
                  fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification card
// ---------------------------------------------------------------------------

class _NotificationCard extends StatelessWidget {
  final _AppNotification notification;
  final IconData icon;
  final Color iconColor;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.lightTextHint,
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
