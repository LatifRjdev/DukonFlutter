import '../../../core/errors/app_message.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../pages/settings/payment_status.dart';
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
      // Two calls: GET /subscription does not carry payments, so the history
      // list this screen renders was always empty and its section never
      // appeared. The payments endpoint existed all along and nothing called
      // it — the UI, the l10n keys, the state field and the route were all
      // present but never connected.
      final res = await _dioClient.get('/stores/${event.storeId}/subscription');
      final data = res.data as Map<String, dynamic>? ?? {};
      // History is secondary: if it fails, the plan card, the limits and the
      // plan-change flow must still render. Future.wait would have replaced
      // the whole screen with an error because the least important request on
      // it failed.
      List<dynamic> payments = const [];
      try {
        final paid = await _dioClient.get(
          '/stores/${event.storeId}/subscription/payments',
        );
        payments = paid.data as List<dynamic>? ?? const [];
      } catch (_) {
        // Degrades to the pre-existing behaviour: the history section hides
        // itself when the list is empty.
      }
      emit(_mapLoaded({...data, 'payments': payments}));
    } catch (e) {
      emit(SubscriptionError(mapErrorToAppMessage(e)));
    }
  }

  Future<void> _onReceiptUploaded(
    SubscriptionReceiptUploaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionUploading());

    // Order matters, and it used to be reversed. The receipt attaches to a
    // Payment row, and that row is created by request-change — so the request
    // has to come first and its id has to be carried into the upload path.
    // Reversed, the upload had no id, hit a route that does not exist
    // (`upload-receipt` without `/:paymentId`), 404'd, and the request never
    // ran at all: paying by card recorded nothing.
    final String paymentId;
    try {
      final response = await _dioClient.post<dynamic>(
        '/stores/${event.storeId}/subscription/request-change',
        data: {'plan': event.plan, 'paymentMethod': event.paymentMethod},
      );
      final id = (response.data as Map<String, dynamic>?)?['id'] as String?;
      if (id == null || id.isEmpty) {
        // Stop rather than POST to a path ending in `/null`, which would 404
        // exactly like the bug this replaces and look the same in the logs.
        emit(const SubscriptionError(AppMessage.unknownError));
        return;
      }
      paymentId = id;
    } catch (e) {
      emit(SubscriptionError(mapErrorToAppMessage(e)));
      return;
    }

    // Past this point the request exists. An upload failure must NOT read as a
    // flat failure: requestChange does not de-duplicate pending payments, so a
    // merchant who resubmitted would create a second request for the same plan.
    try {
      final formData = FormData.fromMap({
        // Named 'file' because the route is FileInterceptor('file', ...) —
        // subscriptions.controller.ts:95. It used to be 'receipt'.
        'file': await MultipartFile.fromFile(
          event.receiptPath,
          filename: 'receipt.jpg',
        ),
      });
      await _dioClient.post<dynamic>(
        '/stores/${event.storeId}/subscription/upload-receipt/$paymentId',
        data: formData,
      );
      emit(const SubscriptionActionSuccess(AppMessage.subscriptionRequestSent));
    } catch (_) {
      emit(
        const SubscriptionActionSuccess(
          AppMessage.subscriptionRequestSentWithoutReceipt,
        ),
      );
    }

    // Reloads either way, so the pending-payment banner confirms the request
    // exists even when the receipt did not attach.
    add(SubscriptionLoadRequested(storeId: event.storeId));
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
        data: {'plan': event.plan, 'paymentMethod': event.paymentMethod},
      );
      emit(const SubscriptionActionSuccess(AppMessage.subscriptionRequestSent));
      add(SubscriptionLoadRequested(storeId: event.storeId));
    } catch (e) {
      emit(SubscriptionError(mapErrorToAppMessage(e)));
    }
  }

  SubscriptionLoaded _mapLoaded(Map<String, dynamic> data) {
    final paymentsRaw = data['payments'] as List<dynamic>? ?? [];
    final payments = paymentsRaw
        .whereType<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();

    // Derived from the history rather than read from the response: the
    // endpoint sends no `pendingPayment` key, so the banner telling a merchant
    // their request is awaiting approval never appeared.
    //
    // Only EXISTENCE is consumed today — the banner renders a constant string
    // and reads no field off this. Two PENDING rows are reachable, since
    // requestChange creates one without checking for an existing one, so this
    // takes the newest by sorting rather than trusting the server's order.
    final pending =
        payments
            .where(
              (p) => paymentStatusKind(p.status) == PaymentStatusKind.pending,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final PaymentRecord? pendingPayment = pending.isEmpty
        ? null
        : pending.first;

    final limitsRaw = data['limits'] as Map<String, dynamic>?;
    final featuresRaw = data['features'] as Map<String, dynamic>?;

    return SubscriptionLoaded(
      plan: data['plan'] as String? ?? 'START',
      status: data['status'] as String? ?? 'ACTIVE',
      // The response carries `currentPeriodEnd` and `trialEndsAt`; it has
      // never carried `expiresAt` or a pre-computed `trialDaysLeft`. Both
      // branches of the plan card's expiry line therefore produced an empty
      // string, so the card never showed when the subscription runs out.
      expiresAt: _parseDate(data['currentPeriodEnd']),
      trialDaysLeft: _trialDaysLeft(_parseDate(data['trialEndsAt'])),
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

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  /// Days remaining until [trialEndsAt], rounded UP and floored at zero. The
  /// server sends the date; the screen wants a count.
  ///
  /// Rounding up rather than truncating, because a trial is created as
  /// `now + 7 days` and truncation reports the wrong number at both ends: on
  /// the day of signup the difference is seven days minus milliseconds, which
  /// floors to 6, and on the final day with ten hours left it floors to 0 —
  /// telling a merchant the trial is over while it still works.
  static int? _trialDaysLeft(DateTime? trialEndsAt) {
    if (trialEndsAt == null) return null;
    final hours = trialEndsAt.difference(DateTime.now()).inHours;
    if (hours <= 0) return 0;
    return (hours / 24).ceil();
  }
}
