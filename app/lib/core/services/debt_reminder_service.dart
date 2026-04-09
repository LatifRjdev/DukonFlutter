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
  }) async {
    final baseId = saleId.hashCode.abs() % 100000;

    // One day before due date
    final dayBefore = dueDate.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        id: baseId,
        title: 'Напоминание о долге',
        body: '$customerName должен ${debtAmount.toStringAsFixed(2)} сом. Срок оплаты завтра.',
        scheduledDate: dayBefore,
        payload: 'debt:$saleId',
      );
    }

    // On due date
    if (dueDate.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        id: baseId + 1,
        title: 'Срок оплаты долга',
        body: '$customerName должен ${debtAmount.toStringAsFixed(2)} сом. Срок оплаты сегодня!',
        scheduledDate: dueDate,
        payload: 'debt:$saleId',
      );
    }

    // If already overdue
    if (dueDate.isBefore(DateTime.now())) {
      await _notificationService.showNotification(
        id: baseId + 2,
        title: 'Просроченный долг',
        body: '$customerName: просрочен долг ${debtAmount.toStringAsFixed(2)} сом.',
        payload: 'debt:$saleId',
      );
    }
  }

  Future<void> showLowStockAlert({
    required String productName,
    required int currentQuantity,
  }) async {
    final id = productName.hashCode.abs() % 100000 + 50000;
    await _notificationService.showNotification(
      id: id,
      title: 'Мало товара на складе',
      body: '$productName: осталось $currentQuantity шт.',
      payload: 'low_stock:$productName',
    );
  }
}
