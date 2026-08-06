import 'package:equatable/equatable.dart';

// ─── Supporting models ────────────────────────────────────────────────────────

class SubscriptionLimits extends Equatable {
  final int maxStores; // -1 = unlimited
  final int maxProducts;
  final int maxStaff;
  final int maxDiscounts;

  const SubscriptionLimits({
    required this.maxStores,
    required this.maxProducts,
    required this.maxStaff,
    required this.maxDiscounts,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      SubscriptionLimits(
        maxStores: (json['maxStores'] as num?)?.toInt() ?? 1,
        maxProducts: (json['maxProducts'] as num?)?.toInt() ?? 500,
        maxStaff: (json['maxStaff'] as num?)?.toInt() ?? 2,
        maxDiscounts: (json['maxDiscounts'] as num?)?.toInt() ?? 0,
      );

  factory SubscriptionLimits.defaults() => const SubscriptionLimits(
        maxStores: 1,
        maxProducts: 500,
        maxStaff: 2,
        maxDiscounts: 0,
      );

  @override
  List<Object?> get props => [maxStores, maxProducts, maxStaff, maxDiscounts];
}

class SubscriptionFeatures extends Equatable {
  final bool hasReportsAll;
  final bool hasExport;
  final bool hasTelegram;
  final bool hasAllPush;
  final bool hasDelivery;
  final bool hasInventory;
  final bool hasEcommerceIntegration;

  const SubscriptionFeatures({
    required this.hasReportsAll,
    required this.hasExport,
    required this.hasTelegram,
    required this.hasAllPush,
    required this.hasDelivery,
    required this.hasInventory,
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
        hasEcommerceIntegration:
            json['hasEcommerceIntegration'] as bool? ?? false,
      );

  factory SubscriptionFeatures.defaults() => const SubscriptionFeatures(
        hasReportsAll: false,
        hasExport: false,
        hasTelegram: false,
        hasAllPush: false,
        hasDelivery: false,
        hasInventory: false,
        hasEcommerceIntegration: false,
      );

  bool hasFeature(String key) {
    switch (key) {
      case 'hasReportsAll':
        return hasReportsAll;
      case 'hasExport':
        return hasExport;
      case 'hasTelegram':
        return hasTelegram;
      case 'hasAllPush':
        return hasAllPush;
      case 'hasDelivery':
        return hasDelivery;
      case 'hasInventory':
        return hasInventory;
      case 'hasEcommerceIntegration':
        return hasEcommerceIntegration;
      default:
        return true;
    }
  }

  @override
  List<Object?> get props => [
        hasReportsAll,
        hasExport,
        hasTelegram,
        hasAllPush,
        hasDelivery,
        hasInventory,
        hasEcommerceIntegration,
      ];
}

class PaymentRecord extends Equatable {
  final String id;
  final String plan;
  final double amount;
  final String method; // CARD, CASH
  final String status; // PENDING, CONFIRMED, REJECTED
  final DateTime createdAt;
  final String? receiptUrl;
  final String? adminNote;

  const PaymentRecord({
    required this.id,
    required this.plan,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.receiptUrl,
    this.adminNote,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as String? ?? '',
        plan: json['plan'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        method: json['method'] as String? ?? 'CARD',
        status: json['status'] as String? ?? 'PENDING',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        receiptUrl: json['receiptUrl'] as String?,
        adminNote: json['adminNote'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, plan, amount, method, status, createdAt, receiptUrl, adminNote];
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
  final String plan; // START, BUSINESS, PREMIUM
  final String status; // TRIAL, ACTIVE, EXPIRED, CANCELLED
  final DateTime? expiresAt;
  final int? trialDaysLeft;
  final double? adminDiscount;
  final SubscriptionLimits limits;
  final SubscriptionFeatures features;
  final List<PaymentRecord> payments;
  final PaymentRecord? pendingPayment;

  const SubscriptionLoaded({
    required this.plan,
    required this.status,
    required this.limits,
    required this.features,
    required this.payments,
    this.expiresAt,
    this.trialDaysLeft,
    this.adminDiscount,
    this.pendingPayment,
  });

  bool get isExpired => status == 'EXPIRED' || status == 'CANCELLED';
  bool get isActive => status == 'ACTIVE' || status == 'TRIAL';

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
      ];
}

class SubscriptionError extends SubscriptionState {
  final String message;
  const SubscriptionError(this.message);

  @override
  List<Object?> get props => [message];
}

class SubscriptionActionSuccess extends SubscriptionState {
  final String message;
  const SubscriptionActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class SubscriptionUploading extends SubscriptionState {}
