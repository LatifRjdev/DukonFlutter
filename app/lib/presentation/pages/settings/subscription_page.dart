import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_event.dart';
import '../../blocs/subscription/subscription_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../l10n/app_message_l10n.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

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

// Built per-build (not `const`) because plan labels/prices/features now come
// from AppLocalizations, which requires a BuildContext — see
// docs/superpowers/plans/2026-09-28-adr0002-track2-remaining-i18n-migration.md
// Task 1. `label` values ('Старт'/'Бизнес'/'Премиум') stay as literal proper
// nouns (tariff brand names) — see tool/i18n-allowlist.txt.
List<_PlanInfo> _buildPlans(AppLocalizations l10n) => [
  _PlanInfo(
    key: 'START',
    label: 'Старт',
    price: l10n.subscriptionPriceStart,
    features: [
      l10n.subscriptionFeatureStores1,
      l10n.subscriptionFeatureProducts500,
      l10n.subscriptionFeatureEmployees2,
      l10n.subscriptionFeatureSalesReport,
      l10n.subscriptionFeatureCurrencies,
    ],
  ),
  _PlanInfo(
    key: 'BUSINESS',
    label: 'Бизнес',
    price: l10n.subscriptionPriceBusiness,
    features: [
      l10n.subscriptionFeatureStores3,
      l10n.subscriptionFeatureProducts2000,
      l10n.subscriptionFeatureEmployees10,
      l10n.subscriptionFeatureAllReports,
      l10n.settingsTileTelegramBot,
      l10n.deliveryListTitle,
      l10n.inventoryTitle,
      l10n.subscriptionFeatureDiscounts5,
    ],
  ),
  _PlanInfo(
    key: 'PREMIUM',
    label: 'Премиум',
    price: l10n.subscriptionPricePremium,
    features: [
      l10n.subscriptionFeatureStores5,
      l10n.subscriptionFeatureUnlimitedProductsEmployees,
      l10n.subscriptionFeatureExportPdfExcel,
      l10n.subscriptionFeatureUnlimitedDiscounts,
      l10n.subscriptionFeaturePrioritySupport,
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
      context.read<SubscriptionBloc>().add(
        SubscriptionLoadRequested(storeId: _storeId!),
      );
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
        return context.textMuted;
      default:
        return context.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppLocalizations.of(context)!.subscriptionActiveStatus;
      case 'TRIAL':
        return AppLocalizations.of(context)!.subscriptionTrialStatus;
      case 'EXPIRED':
        return AppLocalizations.of(context)!.subscriptionExpiredStatus;
      case 'CANCELLED':
        return AppLocalizations.of(context)!.cancelled;
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
      expiryText = AppLocalizations.of(
        context,
      )!.subscriptionTrialDaysLeftLine('${state.trialDaysLeft}');
    } else if (state.expiresAt != null) {
      final formatted = DateFormat('dd.MM.yyyy').format(state.expiresAt!);
      expiryText = AppLocalizations.of(
        context,
      )!.subscriptionExpiryUntilLine(formatted);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 28,
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(state.status).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  _statusLabel(state.status),
                  style: const TextStyle(
                    fontSize: 12,
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
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  expiryText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if ((state.adminDiscount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              child: Text(
                AppLocalizations.of(context)!.subscriptionAdminDiscountBadge(
                  state.adminDiscount!.toStringAsFixed(0),
                ),
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
        color: context.warningBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.subscriptionPendingBannerText,
              style: const TextStyle(
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
    _PlanInfo plan,
    bool isCurrent,
    SubscriptionLoaded state,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusXl,
                      ),
                    ),
                    child: Text(
                      l10n.subscriptionCurrentPlanBadge,
                      style: const TextStyle(
                        fontSize: 12,
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
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.subscriptionSelectPlanButton,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(
    List<PaymentRecord> payments,
    AppLocalizations l10n,
  ) {
    if (payments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paymentHistory,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
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
        statusLabel = AppLocalizations.of(
          context,
        )!.subscriptionPaymentConfirmedStatus;
        break;
      case 'REJECTED':
        statusColor = AppColors.error;
        statusLabel = AppLocalizations.of(
          context,
        )!.subscriptionPaymentRejectedStatus;
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = AppLocalizations.of(
          context,
        )!.subscriptionPaymentPendingStatus;
    }

    return Semantics(
      label: AppLocalizations.of(
        context,
      )!.a11yPaymentOf(_planLabel(payment.plan)),
      button: true,
      child: GestureDetector(
        onTap: () => _showPaymentDetail(payment),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt),
                      style: TextStyle(fontSize: 12, color: context.textMuted),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.bg,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                        ),
                        child: Text(
                          payment.method == 'CARD'
                              ? AppLocalizations.of(context)!.card
                              : AppLocalizations.of(context)!.cash,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetail(PaymentRecord payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.of(
            ctx,
          )!.subscriptionPaymentDialogTitle(_planLabel(payment.plan)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(ctx)!.subscriptionPaymentAmountLine(
                payment.amount.toStringAsFixed(0),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(ctx)!.subscriptionPaymentMethodLine(
                payment.method == 'CARD'
                    ? AppLocalizations.of(ctx)!.subscriptionCardTransferMethod
                    : AppLocalizations.of(ctx)!.cash,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(
                ctx,
              )!.subscriptionPaymentStatusLine(payment.status),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(ctx)!.subscriptionPaymentDateLine(
                DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt),
              ),
            ),
            if (payment.adminNote != null && payment.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(
                  ctx,
                )!.subscriptionAdminNoteLine(payment.adminNote!),
              ),
            ],
            if (payment.receiptUrl != null &&
                payment.receiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(ctx)!.subscriptionReceiptLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: Image.network(
                  payment.receiptUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx2, err, st) => Text(
                    AppLocalizations.of(
                      ctx,
                    )!.subscriptionReceiptImageUnavailable,
                    style: TextStyle(color: context.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.close),
          ),
        ],
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionActionSuccess) {
          AppSnackbar.success(context, state.message.resolve(l10n));
        }
        if (state is SubscriptionError) {
          AppSnackbar.error(context, state.message.resolve(l10n));
        }
      },
      child: Scaffold(
        backgroundColor: context.bg,
        appBar: AppBar(
          title: Text(l10n.settingsSectionSubscription),
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
                    Text(
                      state.message.resolve(l10n),
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    if (_storeId != null)
                      TextButton(
                        onPressed: () => context.read<SubscriptionBloc>().add(
                          SubscriptionLoadRequested(storeId: _storeId!),
                        ),
                        child: Text(l10n.retry),
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
                    SubscriptionLoadRequested(storeId: _storeId!),
                  );
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
                    Text(
                      l10n.subscriptionPlansSectionTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildPlans(l10n).map(
                      (plan) => _buildPlanCard(
                        plan,
                        plan.key == state.plan,
                        state,
                        l10n,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Payment history ────────────────────────────────
                    _buildPaymentHistory(state.payments, l10n),
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
              title: Text(AppLocalizations.of(ctx)!.subscriptionCameraSource),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(ctx)!.subscriptionGallerySource),
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

    widget.bloc.add(
      SubscriptionReceiptUploaded(
        storeId: widget.storeId,
        plan: widget.planKey,
        paymentMethod: 'CARD',
        receiptPath: picked.path,
      ),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _submitCash() {
    widget.bloc.add(
      SubscriptionPlanChangeRequested(
        storeId: widget.storeId,
        plan: widget.planKey,
        paymentMethod: 'CASH',
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plans = _buildPlans(l10n);
    final planInfo = plans.firstWhere(
      (p) => p.key == widget.planKey,
      orElse: () => plans.first,
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
                color: context.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(
              context,
            )!.subscriptionPaymentSheetTitle(planInfo.label),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            planInfo.price,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 20),

          if (!_showCardDetails) ...[
            // Method selection
            _MethodTile(
              icon: Icons.credit_card_outlined,
              label: AppLocalizations.of(
                context,
              )!.subscriptionCardTransferMethod,
              onTap: () => setState(() => _showCardDetails = true),
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.payments_outlined,
              label: AppLocalizations.of(context)!.cash,
              onTap: _submitCash,
            ),
          ] else ...[
            // Card details
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.subscriptionTransferDetailsTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CardDetailRow(
                    label: AppLocalizations.of(context)!.card,
                    value: '4276 3800 1234 5678',
                  ),
                  const SizedBox(height: 6),
                  _CardDetailRow(
                    label: AppLocalizations.of(
                      context,
                    )!.subscriptionRecipientLabel,
                    value: 'DukonPro LLC',
                  ),
                  const SizedBox(height: 6),
                  _CardDetailRow(
                    label: AppLocalizations.of(context)!.subscriptionBankLabel,
                    value: 'Эсхата',
                  ),
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
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_outlined, size: 18),
                label: Text(
                  _uploading
                      ? AppLocalizations.of(context)!.loading
                      : AppLocalizations.of(
                          context,
                        )!.subscriptionUploadReceiptButton,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showCardDetails = false),
              child: Text(AppLocalizations.of(context)!.back),
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
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textMuted),
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
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
