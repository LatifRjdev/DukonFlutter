import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';

// ─── Minimal in-page model ───────────────────────────────────────────────────

enum DeliveryStatus { newOrder, inTransit, delivered }

class _Delivery {
  final String id;
  final String orderNumber;
  final String customerName;
  final String address;
  final double amount;
  final DeliveryStatus status;
  final DateTime createdAt;

  const _Delivery({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.address,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory _Delivery.fromJson(Map<String, dynamic> j) => _Delivery(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String? ?? '#${j['id']}',
        customerName: j['customerName'] as String? ?? '',
        address: j['address'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        status: _statusFromString(j['status'] as String? ?? ''),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  static DeliveryStatus _statusFromString(String s) {
    switch (s.toUpperCase()) {
      case 'IN_TRANSIT':
        return DeliveryStatus.inTransit;
      case 'DELIVERED':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.newOrder;
    }
  }
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

abstract class _DeliveryListState {}

class _DeliveryListInitial extends _DeliveryListState {}

class _DeliveryListLoading extends _DeliveryListState {}

class _DeliveryListLoaded extends _DeliveryListState {
  final List<_Delivery> deliveries;
  _DeliveryListLoaded(this.deliveries);
}

class _DeliveryListError extends _DeliveryListState {
  final String message;
  _DeliveryListError(this.message);
}

class _DeliveryListCubit extends Cubit<_DeliveryListState> {
  final DioClient _client;
  final String storeId;

  _DeliveryListCubit(this._client, this.storeId) : super(_DeliveryListInitial());

  Future<void> load({String? status, DateTime? from, DateTime? to}) async {
    emit(_DeliveryListLoading());
    try {
      final resp = await _client.get(
        '/stores/$storeId/deliveries',
        queryParameters: {
          'status': status,
          'from': from?.toIso8601String(),
          'to': to?.toIso8601String(),
        }..removeWhere((_, v) => v == null),
      );
      final raw = resp.data;
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else {
        list = [];
      }
      emit(_DeliveryListLoaded(list.map((e) => _Delivery.fromJson(e as Map<String, dynamic>)).toList()));
    } catch (e) {
      emit(_DeliveryListError(e.toString()));
    }
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class DeliveryListPage extends StatelessWidget {
  final String storeId;

  const DeliveryListPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _DeliveryListCubit(sl<DioClient>(), storeId)..load(),
      child: _DeliveryListView(storeId: storeId),
    );
  }
}

class _DeliveryListView extends StatefulWidget {
  final String storeId;
  const _DeliveryListView({required this.storeId});

  @override
  State<_DeliveryListView> createState() => _DeliveryListViewState();
}

class _DeliveryListViewState extends State<_DeliveryListView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (label: 'Все', status: null),
    (label: 'Новые', status: 'NEW'),
    (label: 'В пути', status: 'IN_TRANSIT'),
    (label: 'Доставлены', status: 'DELIVERED'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _reload(_tabs[_tabController.index].status);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload(String? status) {
    context.read<_DeliveryListCubit>().load(status: status);
  }

  String _formatPrice(double v) => '${NumberFormat('#,##0', 'ru').format(v)} TJS';

  String _formatDate(DateTime d) => DateFormat('dd.MM.yy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Доставки', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.lightTextSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/deliveries/create', extra: widget.storeId),
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
      body: BlocBuilder<_DeliveryListCubit, _DeliveryListState>(
        builder: (context, state) {
          if (state is _DeliveryListLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is _DeliveryListError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _reload(_tabs[_tabController.index].status),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          if (state is _DeliveryListLoaded) {
            if (state.deliveries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.disabled),
                    const SizedBox(height: AppConstants.spacingMd),
                    const Text('Доставок пока нет',
                        style: TextStyle(fontFamily: 'Inter', color: AppColors.lightTextSecondary, fontSize: 16)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(_tabs[_tabController.index].status),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                itemCount: state.deliveries.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spacingSm),
                itemBuilder: (ctx, i) => _DeliveryCard(
                  delivery: state.deliveries[i],
                  formatPrice: _formatPrice,
                  formatDate: _formatDate,
                  onTap: () => context.push(
                    '/deliveries/${state.deliveries[i].id}',
                    extra: {'storeId': widget.storeId, 'deliveryId': state.deliveries[i].id},
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Card widget ─────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final _Delivery delivery;
  final String Function(double) formatPrice;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _DeliveryCard({
    required this.delivery,
    required this.formatPrice,
    required this.formatDate,
    required this.onTap,
  });

  Color get _statusColor {
    switch (delivery.status) {
      case DeliveryStatus.newOrder:
        return AppColors.info;
      case DeliveryStatus.inTransit:
        return AppColors.warning;
      case DeliveryStatus.delivered:
        return AppColors.success;
    }
  }

  String get _statusLabel {
    switch (delivery.status) {
      case DeliveryStatus.newOrder:
        return 'Новый';
      case DeliveryStatus.inTransit:
        return 'В пути';
      case DeliveryStatus.delivered:
        return 'Доставлен';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(delivery.orderNumber,
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          fontFamily: 'Inter', color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.lightTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(delivery.customerName,
                        style:
                            const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.lightTextSecondary))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.lightTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(delivery.address,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.lightTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Row(
              children: [
                Text(formatPrice(delivery.amount),
                    style: const TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                const Spacer(),
                Text(formatDate(delivery.createdAt),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.lightTextHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
