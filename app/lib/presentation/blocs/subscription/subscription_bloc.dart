import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final DioClient _dioClient;

  SubscriptionBloc({required DioClient dioClient})
      : _dioClient = dioClient,
        super(SubscriptionInitial()) {
    on<SubscriptionLoadRequested>(_onLoadRequested);
    on<SubscriptionReceiptUploaded>(_onReceiptUploaded);
    on<SubscriptionPlanChangeRequested>(_onPlanChangeRequested);
  }

  Future<void> _onLoadRequested(
    SubscriptionLoadRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final res =
          await _dioClient.get('/stores/${event.storeId}/subscription');
      final data = res.data as Map<String, dynamic>? ?? {};
      emit(_mapLoaded(data));
    } catch (e) {
      emit(SubscriptionError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onReceiptUploaded(
    SubscriptionReceiptUploaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionUploading());
    try {
      // 1. Upload receipt image
      final file = File(event.receiptPath);
      final formData = FormData.fromMap({
        'receipt': await MultipartFile.fromFile(
          file.path,
          filename: 'receipt.jpg',
        ),
      });
      await _dioClient.post(
        '/stores/${event.storeId}/subscription/upload-receipt',
        data: formData,
      );

      // 2. Create change request
      await _dioClient.post(
        '/stores/${event.storeId}/subscription/request-change',
        data: {
          'plan': event.plan,
          'paymentMethod': event.paymentMethod,
        },
      );

      emit(const SubscriptionActionSuccess(
          'Заявка отправлена, ожидайте подтверждения'));

      // Reload
      add(SubscriptionLoadRequested(storeId: event.storeId));
    } catch (e) {
      emit(SubscriptionError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPlanChangeRequested(
    SubscriptionPlanChangeRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    // If no receipt path (cash payment), just submit the request directly
    emit(SubscriptionUploading());
    try {
      await _dioClient.post(
        '/stores/${event.storeId}/subscription/request-change',
        data: {
          'plan': event.plan,
          'paymentMethod': event.paymentMethod,
        },
      );
      emit(const SubscriptionActionSuccess(
          'Заявка отправлена, ожидайте подтверждения'));
      add(SubscriptionLoadRequested(storeId: event.storeId));
    } catch (e) {
      emit(SubscriptionError(mapErrorToUserMessage(e)));
    }
  }

  SubscriptionLoaded _mapLoaded(Map<String, dynamic> data) {
    final paymentsRaw = data['payments'] as List<dynamic>? ?? [];
    final payments = paymentsRaw
        .whereType<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();

    final pendingRaw = data['pendingPayment'] as Map<String, dynamic>?;
    final pendingPayment =
        pendingRaw != null ? PaymentRecord.fromJson(pendingRaw) : null;

    final limitsRaw = data['limits'] as Map<String, dynamic>?;
    final featuresRaw = data['features'] as Map<String, dynamic>?;

    return SubscriptionLoaded(
      plan: data['plan'] as String? ?? 'START',
      status: data['status'] as String? ?? 'ACTIVE',
      expiresAt: data['expiresAt'] != null
          ? DateTime.tryParse(data['expiresAt'] as String)
          : null,
      trialDaysLeft: (data['trialDaysLeft'] as num?)?.toInt(),
      adminDiscount: (data['adminDiscount'] as num?)?.toDouble(),
      limits: limitsRaw != null
          ? SubscriptionLimits.fromJson(limitsRaw)
          : SubscriptionLimits.defaults(),
      features: featuresRaw != null
          ? SubscriptionFeatures.fromJson(featuresRaw)
          : SubscriptionFeatures.defaults(),
      payments: payments,
      pendingPayment: pendingPayment,
    );
  }
}
