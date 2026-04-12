import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_event.dart';
import '../../blocs/subscription/subscription_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

// ─── Plan metadata ────────────────────────────────────────────────────────────

class _PlanInfo {
  final String key;
  final String label;
  final String price;
  final List<String> features;

  const _PlanInfo({
    required this.key,
    required this.label,
    required this.price,
    required this.features,
  });
}

const _plans = [
  _PlanInfo(
    key: 'START',
    label: 'Старт',
    price: '49 TJS/мес',
    features: [
      '1 магазин',
      '500 товаров',
      '2 сотрудника',
      'Отчёт продаж',
      'Валюты',
    ],
  ),
  _PlanInfo(
    key: 'BUSINESS',
    label: 'Бизнес',
    price: '149 TJS/мес',
    features: [
      '3 магазина',
      '2000 товаров',
      '10 сотрудников',
      'Все отчёты',
      'Telegram-бот',
      'Доставки',
      'Инвентаризация',
      '5 скидок',
    ],
  ),
  _PlanInfo(
    key: 'PREMIUM',
    label: 'Премиум',
    price: '299 TJS/мес',
    features: [
      '5 магазинов',
      'Безлимит товаров/сотрудников',
      'Экспорт PDF/Excel',
      'Безлимит скидок',
      'Приоритетная поддержка',
    ],
  ),
];

// ─── Page ─────────────────────────────────────────────────────────────────────

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  String? _storeId;

  @override
  void initState() {
    super.initState();
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded) {
      _storeId = storeState.selectedStore?.id;
    }
    if (_storeId != null) {
      context
          .read<SubscriptionBloc>()
          .add(SubscriptionLoadRequested(storeId: _storeId!));
    }
  }

  // ─── Status helpers ──────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'TRIAL':
        return AppColors.info;
      case 'EXPIRED':
        return AppColors.error;
      case 'CANCELLED':
        return AppColors.lightTextHint;
      default:
        return AppColors.lightTextHint;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Активна';
      case 'TRIAL':
        return 'Пробный период';
      case 'EXPIRED':
        return 'Истекла';
      case 'CANCELLED':
        return 'Отменена';
      default:
        return status;
    }
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'START':
        return 'Старт';
      case 'BUSINESS':
        return 'Бизнес';
      case 'PREMIUM':
        return 'Премиум';
      default:
        return plan;
    }
  }

  // ─── Payment flow ─────────────────────────────────────────────────────────

  void _onSelectPlan(String planKey) {
    if (_storeId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentMethodSheet(
        planKey: planKey,
        storeId: _storeId!,
        bloc: context.read<SubscriptionBloc>(),
      ),
    );
  }

  // ─── Build helpers ────────────────────────────────────────────────────────

  Widget _buildCurrentPlanCard(SubscriptionLoaded state) {
    final isExpired = state.isExpired;
    final gradient = isExpired
        ? const LinearGradient(
            colors: [Color(0xFF757575), Color(0xFF9E9E9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    String expiryText = '';
    if (state.status == 'TRIAL' && state.trialDaysLeft != null) {
      expiryText = 'Пробный период: осталось ${state.trialDaysLeft} дней';
    } else if (state.expiresAt != null) {
      final formatted = DateFormat('dd.MM.yyyy').format(state.expiresAt!);
      expiryText = 'до $formatted';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text(
                _planLabel(state.plan),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(state.status).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  _statusLabel(state.status),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (expiryText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(expiryText,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          if ((state.adminDiscount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Скидка ${state.adminDiscount!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Text('⏳', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ожидает подтверждения оплаты',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
      _PlanInfo plan, bool isCurrent, SubscriptionLoaded state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? AppColors.primary : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.price,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Текущий план',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _onSelectPlan(plan.key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Выбрать',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 15, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.lightTextSecondary)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(List<PaymentRecord> payments) {
    if (payments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'История оплат',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 8),
        ...payments.map((p) => _buildPaymentTile(p)),
      ],
    );
  }

  Widget _buildPaymentTile(PaymentRecord payment) {
    Color statusColor;
    String statusLabel;
    switch (payment.status) {
      case 'CONFIRMED':
        statusColor = AppColors.success;
        statusLabel = 'Подтверждено';
        break;
      case 'REJECTED':
        statusColor = AppColors.error;
        statusLabel = 'Отклонено';
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Ожидает';
    }

    return GestureDetector(
      onTap: () => _showPaymentDetail(payment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _planLabel(payment.plan),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightTextHint),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${payment.amount.toStringAsFixed(0)} TJS',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payment.method == 'CARD' ? 'Карта' : 'Наличные',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.lightTextSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetail(PaymentRecord payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Платёж — ${_planLabel(payment.plan)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сумма: ${payment.amount.toStringAsFixed(0)} TJS'),
            const SizedBox(height: 6),
            Text(
                'Метод: ${payment.method == 'CARD' ? 'Перевод на карту' : 'Наличные'}'),
            const SizedBox(height: 6),
            Text('Статус: ${payment.status}'),
            const SizedBox(height: 6),
            Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt)}'),
            if (payment.adminNote != null && payment.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Примечание: ${payment.adminNote}'),
            ],
            if (payment.receiptUrl != null && payment.receiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Чек:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  payment.receiptUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx2, err, st) => const Text(
                    'Изображение недоступно',
                    style: TextStyle(color: AppColors.lightTextHint),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        }
        if (state is SubscriptionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('Подписка'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
        ),
        body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, state) {
            if (state is SubscriptionLoading ||
                state is SubscriptionUploading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SubscriptionError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.message,
                        style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 16),
                    if (_storeId != null)
                      TextButton(
                        onPressed: () => context
                            .read<SubscriptionBloc>()
                            .add(SubscriptionLoadRequested(
                                storeId: _storeId!)),
                        child: const Text('Повторить'),
                      ),
                  ],
                ),
              );
            }

            if (state is! SubscriptionLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (_storeId != null) {
                  context.read<SubscriptionBloc>().add(
                      SubscriptionLoadRequested(storeId: _storeId!));
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Current plan card ──────────────────────────────
                    _buildCurrentPlanCard(state),
                    const SizedBox(height: 16),

                    // ── Pending payment banner ─────────────────────────
                    if (state.pendingPayment != null) ...[
                      _buildPendingBanner(),
                      const SizedBox(height: 16),
                    ],

                    // ── Plan selection ─────────────────────────────────
                    const Text(
                      'Тарифные планы',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 8),
                    ..._plans.map((plan) => _buildPlanCard(
                          plan,
                          plan.key == state.plan,
                          state,
                        )),

                    const SizedBox(height: 8),

                    // ── Payment history ────────────────────────────────
                    _buildPaymentHistory(state.payments),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Payment method bottom sheet ──────────────────────────────────────────────

class _PaymentMethodSheet extends StatefulWidget {
  final String planKey;
  final String storeId;
  final SubscriptionBloc bloc;

  const _PaymentMethodSheet({
    required this.planKey,
    required this.storeId,
    required this.bloc,
  });

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  bool _showCardDetails = false;
  bool _uploading = false;

  Future<void> _pickAndUploadReceipt() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _uploading = true);

    widget.bloc.add(SubscriptionReceiptUploaded(
      storeId: widget.storeId,
      plan: widget.planKey,
      paymentMethod: 'CARD',
      receiptPath: picked.path,
    ));

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _submitCash() {
    widget.bloc.add(SubscriptionPlanChangeRequested(
      storeId: widget.storeId,
      plan: widget.planKey,
      paymentMethod: 'CASH',
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final planInfo = _plans.firstWhere(
      (p) => p.key == widget.planKey,
      orElse: () => _plans.first,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Оплата тарифа «${planInfo.label}»',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            planInfo.price,
            style: const TextStyle(
                fontSize: 14, color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 20),

          if (!_showCardDetails) ...[
            // Method selection
            _MethodTile(
              icon: Icons.credit_card_outlined,
              label: 'Перевод на карту',
              onTap: () => setState(() => _showCardDetails = true),
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.payments_outlined,
              label: 'Наличные',
              onTap: _submitCash,
            ),
          ] else ...[
            // Card details
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Реквизиты для перевода',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  _CardDetailRow(label: 'Карта', value: '4276 3800 1234 5678'),
                  SizedBox(height: 6),
                  _CardDetailRow(label: 'Получатель', value: 'DokonPro LLC'),
                  SizedBox(height: 6),
                  _CardDetailRow(label: 'Банк', value: 'Эсхата'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _pickAndUploadReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.buttonRadius),
                  ),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_outlined, size: 18),
                label: Text(_uploading ? 'Загрузка...' : 'Я перевёл — загрузить чек'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showCardDetails = false),
              child: const Text('Назад'),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.lightTextHint),
          ],
        ),
      ),
    );
  }
}

class _CardDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _CardDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.lightTextSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
