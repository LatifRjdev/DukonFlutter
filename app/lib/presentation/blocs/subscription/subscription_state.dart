import 'package:equatable/equatable.dart';
import '../../../core/errors/app_message.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../pages/settings/subscription_status.dart';

// ─── Supporting models ────────────────────────────────────────────────────────

// `maxStores` was removed here in 2026-10: the column was dropped from
// SubscriptionPlanConfig in 2026-05 (see api/src/common/guards/plan-limit.helper.ts)
// because each store carries its own subscription, so a per-merchant store cap
// had no architectural anchor. This class kept reading it with a `?? 1`
// fallback, so it silently read as 1 forever, and seven test references kept it
// looking real — three `.having` assertions and four fixture literals. Nothing
// rendered it, which is why there was no visible defect to notice.
class SubscriptionLimits extends Equatable {
  final int maxProducts;
  final int maxStaff;
  final int maxDiscounts;

  const SubscriptionLimits({
    required this.maxProducts,
    required this.maxStaff,
    required this.maxDiscounts,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      SubscriptionLimits(
        maxProducts: (json['maxProducts'] as num?)?.toInt() ?? 500,
        maxStaff: (json['maxStaff'] as num?)?.toInt() ?? 2,
        maxDiscounts: (json['maxDiscounts'] as num?)?.toInt() ?? 0,
      );

  factory SubscriptionLimits.defaults() =>
      const SubscriptionLimits(maxProducts: 500, maxStaff: 2, maxDiscounts: 0);

  @override
  List<Object?> get props => [maxProducts, maxStaff, maxDiscounts];
}

// Mirrors `PLAN_FEATURE_FLAGS` in
// api/src/modules/subscriptions/plan-view.ts, which is itself checked against
// `model SubscriptionPlanConfig` in schema.prisma by plan-view.spec.ts. This
// list used to be hand-kept on both sides — the old comment here said so — and
// four flags were added to one side only. Three of those four are enforced with
// @RequiresFeature on whole controllers, so the app could not gate zakat,
// loyalty or batch profitability and merchants met a 403 instead.
class SubscriptionFeatures extends Equatable {
  final bool hasReportsAll;
  final bool hasExport;
  final bool hasTelegram;
  final bool hasAllPush;
  final bool hasDelivery;
  final bool hasInventory;
  final bool hasZakat;
  final bool hasInvestments;
  final bool hasLoyalty;
  final bool hasBatchProfitability;
  final bool hasEcommerceIntegration;

  const SubscriptionFeatures({
    required this.hasReportsAll,
    required this.hasExport,
    required this.hasTelegram,
    required this.hasAllPush,
    required this.hasDelivery,
    required this.hasInventory,
    required this.hasZakat,
    required this.hasInvestments,
    required this.hasLoyalty,
    required this.hasBatchProfitability,
    required this.hasEcommerceIntegration,
  });

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) =>
      SubscriptionFeatures(
        hasReportsAll: json['hasReportsAll'] as bool? ?? false,
        hasExport: json['hasExport'] as bool? ?? false,
        hasTelegram: json['hasTelegram'] as bool? ?? false,
        hasAllPush: json['hasAllPush'] as bool? ?? false,
        hasDelivery: json['hasDelivery'] as bool? ?? false,
        hasInventory: json['hasInventory'] as bool? ?? false,
        hasZakat: json['hasZakat'] as bool? ?? false,
        hasInvestments: json['hasInvestments'] as bool? ?? false,
        hasLoyalty: json['hasLoyalty'] as bool? ?? false,
        hasBatchProfitability: json['hasBatchProfitability'] as bool? ?? false,
        hasEcommerceIntegration:
            json['hasEcommerceIntegration'] as bool? ?? false,
      );

  // `?? false` throughout, and defaults are all false: an absent flag denies.
  // The deleted `hasFeature(String)` did the opposite — `default: return true`
  // — against a server helper documented as fail-closed precisely so a
  // misconfigured plan cannot silently unlock a paid feature.
  factory SubscriptionFeatures.defaults() => const SubscriptionFeatures(
    hasReportsAll: false,
    hasExport: false,
    hasTelegram: false,
    hasAllPush: false,
    hasDelivery: false,
    hasInventory: false,
    hasZakat: false,
    hasInvestments: false,
    hasLoyalty: false,
    hasBatchProfitability: false,
    hasEcommerceIntegration: false,
  );

  @override
  List<Object?> get props => [
    hasReportsAll,
    hasExport,
    hasTelegram,
    hasAllPush,
    hasDelivery,
    hasInventory,
    hasZakat,
    hasInvestments,
    hasLoyalty,
    hasBatchProfitability,
    hasEcommerceIntegration,
  ];
}

/// One plan as offered to THIS merchant: [price] already has their
/// `adminDiscount` applied, server-side, by the same helper `request-change`
/// uses to compute what they will be charged.
class SubscriptionPlanOption extends Equatable {
  final String plan;
  final double price;
  final double listPrice;
  final int maxProducts;
  final int maxStaff;
  final int maxDiscounts;
  final SubscriptionFeatures features;

  const SubscriptionPlanOption({
    required this.plan,
    required this.price,
    required this.listPrice,
    required this.maxProducts,
    required this.maxStaff,
    required this.maxDiscounts,
    required this.features,
  });

  bool get isDiscounted => price < listPrice;

  factory SubscriptionPlanOption.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanOption(
        plan: json['plan'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        listPrice: (json['listPrice'] as num?)?.toDouble() ?? 0,
        maxProducts: (json['maxProducts'] as num?)?.toInt() ?? 0,
        maxStaff: (json['maxStaff'] as num?)?.toInt() ?? 0,
        maxDiscounts: (json['maxDiscounts'] as num?)?.toInt() ?? 0,
        features: SubscriptionFeatures.fromJson(
          (json['features'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  @override
  List<Object?> get props => [
    plan,
    price,
    listPrice,
    maxProducts,
    maxStaff,
    maxDiscounts,
    features,
  ];
}

class PaymentRecord extends Equatable {
  final String id;
  final double amount;
  // Both are raw server enum values. Named rather than listed: a restated list
  // is what rots. `// CARD, CASH` omitted MOBILE_TRANSFER, and
  // `// PENDING, CONFIRMED, REJECTED` named three of six and invented one —
  // CONFIRMED has never been in PaymentStatus, which is precisely the mistake
  // that made an approved payment read "Ожидает" until PR #85.
  final String method; // enum PaymentMethod in api/prisma/schema.prisma
  final String status; // enum PaymentStatus — read via paymentStatusKind()
  final DateTime createdAt;
  final String? receiptUrl;
  final String? adminNote;

  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.receiptUrl,
    this.adminNote,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
    id: json['id'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    method: json['method'] as String? ?? 'CARD',
    status: json['status'] as String? ?? 'PENDING',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)?.toLocal() ??
              DateTime.now()
        : DateTime.now(),
    // The column is `receiptImage` and holds a path relative to the API
    // host, not a URL. Reading 'receiptUrl' meant the receipt block never
    // rendered; keeping it relative would have meant Image.network failing
    // on every one.
    receiptUrl: _receiptUrl(json['receiptImage'] as String?),
    // `rejectionReason` is the admin's reason for refusing; `note` is the
    // general note a request carries. The old key 'adminNote' is neither,
    // so a rejected payment never showed why.
    adminNote:
        (json['rejectionReason'] as String?) ?? (json['note'] as String?),
  );

  /// `receiptImage` is stored as e.g. `uploads/receipts/abc.jpg`.
  static String? _receiptUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final base = ApiEndpoints.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
  }

  @override
  List<Object?> get props => [
    id,
    amount,
    method,
    status,
    createdAt,
    receiptUrl,
    adminNote,
  ];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {}

class SubscriptionLoading extends SubscriptionState {}

class SubscriptionLoaded extends SubscriptionState {
  final String plan; // enum SubscriptionPlan: START, BUSINESS, PREMIUM
  /// Raw `enum SubscriptionStatus` from `api/prisma/schema.prisma`. Read it via
  /// [kind] rather than comparing strings here: this comment listed four of the
  /// five values until 2026-10, omitting the one the file had no handling for —
  /// PAST_DUE — and [kind]'s mapping is tested against the schema, so it cannot
  /// drift the same way.
  final String status;
  final DateTime? expiresAt;
  final int? trialDaysLeft;
  final double? adminDiscount;
  final SubscriptionLimits limits;
  final SubscriptionFeatures features;
  final List<PaymentRecord> payments;
  final PaymentRecord? pendingPayment;

  /// Every plan as offered to this merchant, priced with their discount
  /// already applied server-side. Empty when the response omits it — never
  /// invented — so the card list can render an error instead of a price
  /// nobody promised.
  final List<SubscriptionPlanOption> availablePlans;

  const SubscriptionLoaded({
    required this.plan,
    required this.status,
    required this.limits,
    required this.features,
    required this.payments,
    required this.availablePlans,
    this.expiresAt,
    this.trialDaysLeft,
    this.adminDiscount,
    this.pendingPayment,
  });

  /// The server's gate, stated once: `feature-flag.helper.ts` allows ACTIVE and
  /// TRIAL and refuses everything else.
  bool get isActive =>
      kind == SubscriptionStatusKind.active ||
      kind == SubscriptionStatusKind.trial;

  /// Deliberately the negation of [isActive] and not a second list. It used to
  /// be `EXPIRED || CANCELLED`, which left PAST_DUE in neither — so the plan
  /// card, whose gradient this getter chooses, rendered a lapsed subscription
  /// in full colour while the backend refused every gated feature. Anything the
  /// server will refuse has to look refused, including a status this app has
  /// not heard of.
  bool get isExpired => !isActive;

  SubscriptionStatusKind get kind => subscriptionStatusKind(status);

  @override
  List<Object?> get props => [
    plan,
    status,
    expiresAt,
    trialDaysLeft,
    adminDiscount,
    limits,
    features,
    payments,
    pendingPayment,
    availablePlans,
  ];
}

class SubscriptionError extends SubscriptionState {
  final AppMessage message;
  const SubscriptionError(this.message);

  @override
  List<Object?> get props => [message];
}

class SubscriptionActionSuccess extends SubscriptionState {
  final AppMessage message;
  const SubscriptionActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class SubscriptionUploading extends SubscriptionState {}
