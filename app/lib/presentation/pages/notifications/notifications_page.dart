import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum _NotifType { bell, warning, cart, truck, impersonationRequest }

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
      case 'IMPERSONATION_REQUEST':
        type = _NotifType.impersonationRequest;
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

  // Impersonation-request consent: notification.id -> action-in-flight /
  // already-responded, so buttons disable/disappear immediately without
  // needing a full list reload.
  final Set<String> _impersonationRespondingIds = {};
  final Set<String> _impersonationRespondedIds = {};

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
        _error = mapErrorToUserMessage(e);
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
      if (!mounted) return;
      setState(() {
        _notifications[index] = notif.copyWithRead();
      });
    } catch (e) {
      if (!mounted) return;
      // Optimistically update the local read state anyway (it'll be
      // corrected by the next refresh either way), but surface the
      // failure — silently swallowing it meant a notification could look
      // read locally while staying unread on the server, with no
      // indication to the user that the write never landed (SPEC.md audit
      // finding, post-plan).
      setState(() {
        _notifications[index] = notif.copyWithRead();
      });
      AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  // The Notification record carries no structured data field, so a tapped
  // IMPERSONATION_REQUEST notification alone doesn't tell us which
  // ImpersonationRequest to respond to — look the caller's own pending
  // request up via GET /impersonation-requests/pending, then respond to
  // that id. See ImpersonationController.findPending() on the backend.
  Future<void> _respondToImpersonation(
    _AppNotification notif,
    String decision,
  ) async {
    if (_impersonationRespondingIds.contains(notif.id)) return;
    setState(() => _impersonationRespondingIds.add(notif.id));

    try {
      final pendingResp = await sl<DioClient>()
          .get<Map<String, dynamic>>('/impersonation-requests/pending');
      final pending = pendingResp.data;
      final requestId = pending?['id'] as String?;
      if (requestId == null) {
        throw Exception('no pending request');
      }

      await sl<DioClient>().put<void>(
        '/impersonation-requests/$requestId/respond',
        data: {'decision': decision},
      );

      if (!mounted) return;
      setState(() {
        _impersonationRespondingIds.remove(notif.id);
        _impersonationRespondedIds.add(notif.id);
      });
      final idx = _notifications.indexWhere((n) => n.id == notif.id);
      if (idx != -1) await _markRead(idx);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'APPROVED' ? 'Доступ предоставлен' : 'Запрос отклонён',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _impersonationRespondingIds.remove(notif.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось обработать запрос — возможно, он уже неактивен',
            ),
          ),
        );
      }
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
      case _NotifType.impersonationRequest:
        return Icons.support_agent;
      case _NotifType.bell:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(_NotifType type, BuildContext ctx) {
    switch (type) {
      case _NotifType.warning:
        return AppColors.warning;
      case _NotifType.cart:
        return AppColors.primary;
      case _NotifType.truck:
        return AppColors.info;
      case _NotifType.impersonationRequest:
        return AppColors.warning;
      case _NotifType.bell:
        return ctx.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Уведомления',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        backgroundColor: context.surface,
        foregroundColor: context.textPrimary,
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
                          separatorBuilder: (_, _) =>
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
                            final isImpersonation =
                                n.type == _NotifType.impersonationRequest;
                            return _NotificationCard(
                              notification: n,
                              icon: _typeIcon(n.type),
                              iconColor: _typeColor(n.type, context),
                              timeAgo: _timeAgo(n.createdAt),
                              onTap: () => _markRead(i),
                              showImpersonationActions: isImpersonation &&
                                  !_impersonationRespondedIds.contains(n.id),
                              impersonationActionInFlight:
                                  _impersonationRespondingIds.contains(n.id),
                              onApproveImpersonation: isImpersonation
                                  ? () =>
                                      _respondToImpersonation(n, 'APPROVED')
                                  : null,
                              onRejectImpersonation: isImpersonation
                                  ? () =>
                                      _respondToImpersonation(n, 'REJECTED')
                                  : null,
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
              style: TextStyle(color: context.textSecondary)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: context.textMuted),
          const SizedBox(height: 12),
          Text('Нет уведомлений',
              style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondary,
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
  final bool showImpersonationActions;
  final bool impersonationActionInFlight;
  final VoidCallback? onApproveImpersonation;
  final VoidCallback? onRejectImpersonation;

  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.timeAgo,
    required this.onTap,
    this.showImpersonationActions = false,
    this.impersonationActionInFlight = false,
    this.onApproveImpersonation,
    this.onRejectImpersonation,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unread = !notification.isRead;
    return Semantics(
      label: l10n.a11yMarkAsRead,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: unread ? AppColors.primary.withValues(alpha: 0.04) : context.surface,
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
                              color: context.textPrimary,
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
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: context.textMuted,
                      ),
                    ),
                    if (showImpersonationActions) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: impersonationActionInFlight
                                  ? null
                                  : onRejectImpersonation,
                              child: const Text('Отклонить'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: impersonationActionInFlight
                                  ? null
                                  : onApproveImpersonation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: impersonationActionInFlight
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Разрешить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
