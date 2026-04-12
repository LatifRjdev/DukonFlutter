import 'package:equatable/equatable.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionLoadRequested extends SubscriptionEvent {
  final String storeId;
  const SubscriptionLoadRequested({required this.storeId});

  @override
  List<Object?> get props => [storeId];
}

class SubscriptionPlanChangeRequested extends SubscriptionEvent {
  final String storeId;
  final String plan; // START, BUSINESS, PREMIUM
  final String paymentMethod; // CARD, CASH
  final String? receiptPath;

  const SubscriptionPlanChangeRequested({
    required this.storeId,
    required this.plan,
    required this.paymentMethod,
    this.receiptPath,
  });

  @override
  List<Object?> get props => [storeId, plan, paymentMethod, receiptPath];
}

class SubscriptionReceiptUploaded extends SubscriptionEvent {
  final String storeId;
  final String plan;
  final String paymentMethod;
  final String receiptPath;

  const SubscriptionReceiptUploaded({
    required this.storeId,
    required this.plan,
    required this.paymentMethod,
    required this.receiptPath,
  });

  @override
  List<Object?> get props => [storeId, plan, paymentMethod, receiptPath];
}
