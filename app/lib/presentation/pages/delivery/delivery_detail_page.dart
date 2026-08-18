import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

enum _DeliveryStatus { newOrder, inTransit, delivered }

class _DeliveryItem {
  final String name;
  final int qty;
  final double price;
  const _DeliveryItem({required this.name, required this.qty, required this.price});
  factory _DeliveryItem.fromJson(Map<String, dynamic> j) => _DeliveryItem(
        name: j['name'] as String? ?? '',
        qty: (j['qty'] ?? j['quantity'] ?? 1) as int,
        price: (j['price'] as num?)?.toDouble() ?? 0,
      );
}

class _DeliveryDetail {
  final String id;
  final String orderNumber;
  final String customerName;
  final String address;
  final double total;
  final _DeliveryStatus status;
  final List<_DeliveryItem> items;
  final DateTime createdAt;

  const _DeliveryDetail({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.address,
    required this.total,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory _DeliveryDetail.fromJson(Map<String, dynamic> j) => _DeliveryDetail(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String? ?? '#${j['id']}',
        customerName: j['customerName'] as String? ?? '',
        address: j['address'] as String? ?? '',
        total: (j['amount'] ?? j['total'] as num?)?.toDouble() ?? 0,
        status: _statusFrom(j['status'] as String? ?? ''),
        items: ((j['items'] as List?) ?? [])
            .map((e) => _DeliveryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  static _DeliveryStatus _statusFrom(String s) {
    switch (s.toUpperCase()) {
      case 'IN_TRANSIT':
        return _DeliveryStatus.inTransit;
      case 'DELIVERED':
        return _DeliveryStatus.delivered;
      default:
        return _DeliveryStatus.newOrder;
    }
  }
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

abstract class _DetailState {}

class _DetailInitial extends _DetailState {}

class _DetailLoading extends _DetailState {}

class _DetailLoaded extends _DetailState {
  final _DeliveryDetail delivery;
  _DetailLoaded(this.delivery);
}

class _DetailError extends _DetailState {
  final String message;
  _DetailError(this.message);
}

class _DetailActionLoading extends _DetailState {
  final _DeliveryDetail delivery;
  _DetailActionLoading(this.delivery);
}

class _DetailCubit extends Cubit<_DetailState> {
  final DioClient _client;
  final String storeId;
  final String deliveryId;

  _DetailCubit(this._client, this.storeId, this.deliveryId) : super(_DetailInitial());

  Future<void> load() async {
    emit(_DetailLoading());
    try {
      final resp = await _client.get('/stores/$storeId/deliveries/$deliveryId');
      emit(_DetailLoaded(_DeliveryDetail.fromJson(resp.data as Map<String, dynamic>)));
    } catch (e) {
      emit(_DetailError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> updateStatus(String newStatus) async {
    final current = state;
    if (current is! _DetailLoaded) return;
    emit(_DetailActionLoading(current.delivery));
    try {
      await _client.put(
        '/stores/$storeId/deliveries/$deliveryId/status',
        data: {'status': newStatus},
      );
      await load();
    } catch (e) {
      emit(_DetailError(mapErrorToUserMessage(e)));
    }
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class DeliveryDetailPage extends StatelessWidget {
  final String storeId;
  final String deliveryId;

  const DeliveryDetailPage({super.key, required this.storeId, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _DetailCubit(sl<DioClient>(), storeId, deliveryId)..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  String _formatPrice(double v) => '${NumberFormat('#,##0', 'ru').format(v)} TJS';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(l10n.deliveryDetailTitle,
            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: BlocBuilder<_DetailCubit, _DetailState>(
        builder: (context, state) {
          if (state is _DetailLoading || state is _DetailInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is _DetailError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () => context.read<_DetailCubit>().load(),
                      child: Text(l10n.retry)),
                ],
              ),
            );
          }

          final delivery = state is _DetailLoaded
              ? state.delivery
              : (state as _DetailActionLoading).delivery;
          final isActing = state is _DetailActionLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper
                _StatusStepper(status: delivery.status),
                const SizedBox(height: AppConstants.spacingMd),

                // Info card
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: l10n.deliveryDetailOrderLabel, value: delivery.orderNumber),
                      const Divider(height: 20),
                      _InfoRow(label: l10n.deliveryDetailCustomerLabel, value: delivery.customerName),
                      const Divider(height: 20),
                      _InfoRow(label: l10n.deliveryDetailAddressLabel, value: delivery.address),
                      const Divider(height: 20),
                      _InfoRow(
                          label: l10n.date,
                          value: DateFormat('dd.MM.yyyy HH:mm').format(delivery.createdAt)),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),

                // Items
                if (delivery.items.isNotEmpty) ...[
                  Text(l10n.products,
                      style: const TextStyle(
                          fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: AppConstants.spacingSm),
                  _SectionCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < delivery.items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(delivery.items[i].name,
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14))),
                                Text('${delivery.items[i].qty} ${l10n.pcs}',
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: context.textSecondary)),
                                const SizedBox(width: 12),
                                Text(_formatPrice(delivery.items[i].price * delivery.items[i].qty),
                                    style: const TextStyle(
                                        fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(l10n.total,
                                      style: const TextStyle(
                                          fontFamily: 'Inter', fontWeight: FontWeight.w700))),
                              Text(_formatPrice(delivery.total),
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],

                // Action button
                if (delivery.status != _DeliveryStatus.delivered)
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      onPressed: isActing
                          ? null
                          : () => context.read<_DetailCubit>().updateStatus(
                                delivery.status == _DeliveryStatus.newOrder
                                    ? 'IN_TRANSIT'
                                    : 'DELIVERED',
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                      ),
                      child: isActing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onPrimary))
                          : Text(
                              delivery.status == _DeliveryStatus.newOrder
                                  ? l10n.deliveryDetailPickedUpButton
                                  : l10n.deliveryDetailDeliveredButton,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16),
                            ),
                    ),
                  ),

                const SizedBox(height: AppConstants.spacingXl),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Stepper ─────────────────────────────────────────────────────────────────

class _StatusStepper extends StatelessWidget {
  final _DeliveryStatus status;
  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      (label: l10n.deliveryDetailStepCreated, status: _DeliveryStatus.newOrder),
      (label: l10n.deliveryDetailStepInTransit, status: _DeliveryStatus.inTransit),
      (label: l10n.deliveryDetailStepDelivered, status: _DeliveryStatus.delivered),
    ];

    final currentIndex = steps.indexWhere((s) => s.status == status);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepDot(
              label: steps[i].label,
              isActive: i <= currentIndex,
              isCurrent: i == currentIndex,
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < currentIndex ? AppColors.primary : context.border,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isCurrent;

  const _StepDot({required this.label, required this.isActive, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primary : context.border,
            border: isCurrent
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: isActive
              ? const Icon(Icons.check, size: 12, color: AppColors.onPrimary)
              : null,
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: isActive ? AppColors.primary : context.textSecondary,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Inter', fontSize: 13, color: context.textSecondary)),
        ),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
