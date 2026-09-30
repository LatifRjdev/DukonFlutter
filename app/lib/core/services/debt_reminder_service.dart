import 'package:dukonpro/l10n/app_localizations.dart';

import 'notification_service.dart';

class DebtReminderService {
  final NotificationService _notificationService;

  DebtReminderService({required NotificationService notificationService})
      : _notificationService = notificationService;

  Future<void> scheduleDebtReminder({
    required String saleId,
    required String customerName,
    required double debtAmount,
    required DateTime dueDate,
    required AppLocalizations l10n,
  }) async {
    final baseId = saleId.hashCode.abs() % 100000;

    // One day before due date
    final dayBefore = dueDate.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        id: baseId,
        title: l10n.notificationSettingsDebtReminderTitle,
        body: l10n.debtReminderDueTomorrowBody(customerName, debtAmount.toStringAsFixed(2)),
        scheduledDate: dayBefore,
        payload: 'debt:$saleId',
      );
    }

    // On due date
    if (dueDate.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        id: baseId + 1,
        title: l10n.debtReminderDueTodayTitle,
        body: l10n.debtReminderDueTodayBody(customerName, debtAmount.toStringAsFixed(2)),
        scheduledDate: dueDate,
        payload: 'debt:$saleId',
      );
    }

    // If already overdue
    if (dueDate.isBefore(DateTime.now())) {
      await _notificationService.showNotification(
        id: baseId + 2,
        title: l10n.debtReminderOverdueTitle,
        body: l10n.debtReminderOverdueBody(customerName, debtAmount.toStringAsFixed(2)),
        payload: 'debt:$saleId',
      );
    }
  }

  Future<void> showLowStockAlert({
    required String productName,
    required int currentQuantity,
    required AppLocalizations l10n,
  }) async {
    final id = productName.hashCode.abs() % 100000 + 50000;
    await _notificationService.showNotification(
      id: id,
      title: l10n.lowStockAlertTitle,
      body: l10n.lowStockAlertBody(productName, currentQuantity.toString()),
      payload: 'low_stock:$productName',
    );
  }
}
