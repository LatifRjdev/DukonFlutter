import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/core/services/debt_reminder_service.dart';
import 'package:dukonpro/core/services/notification_service.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockNotificationService notificationService;
  late DebtReminderService service;

  setUpAll(() {
    registerFallbackValue(DateTime(2000));
  });

  setUp(() {
    notificationService = MockNotificationService();
    service = DebtReminderService(notificationService: notificationService);

    when(() => notificationService.scheduleNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
    when(() => notificationService.showNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  int expectedBaseId(String saleId) => saleId.hashCode.abs() % 100000;

  group('DebtReminderService.scheduleDebtReminder', () {
    test(
        'schedules a day-before reminder and a due-date reminder when due date is comfortably in the future',
        () async {
      final dueDate = DateTime.now().add(const Duration(days: 5));
      final dayBefore = dueDate.subtract(const Duration(days: 1));
      final baseId = expectedBaseId('sale-1');

      await service.scheduleDebtReminder(
        saleId: 'sale-1',
        customerName: 'Азиз',
        debtAmount: 150.5,
        dueDate: dueDate,
      );

      verify(() => notificationService.scheduleNotification(
            id: baseId,
            title: 'Напоминание о долге',
            body: 'Азиз должен 150.50 сом. Срок оплаты завтра.',
            scheduledDate: dayBefore,
            payload: 'debt:sale-1',
          )).called(1);

      verify(() => notificationService.scheduleNotification(
            id: baseId + 1,
            title: 'Срок оплаты долга',
            body: 'Азиз должен 150.50 сом. Срок оплаты сегодня!',
            scheduledDate: dueDate,
            payload: 'debt:sale-1',
          )).called(1);

      verifyNever(() => notificationService.showNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          ));
    });

    test(
        'schedules only the due-date reminder when due date is within 24 hours (day-before already passed)',
        () async {
      final dueDate = DateTime.now().add(const Duration(hours: 2));
      final baseId = expectedBaseId('sale-2');

      await service.scheduleDebtReminder(
        saleId: 'sale-2',
        customerName: 'Иван',
        debtAmount: 40,
        dueDate: dueDate,
      );

      // day-before reminder (baseId) must NOT be scheduled — it's already in the past.
      verifyNever(() => notificationService.scheduleNotification(
            id: baseId,
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            payload: any(named: 'payload'),
          ));

      verify(() => notificationService.scheduleNotification(
            id: baseId + 1,
            title: 'Срок оплаты долга',
            body: 'Иван должен 40.00 сом. Срок оплаты сегодня!',
            scheduledDate: dueDate,
            payload: 'debt:sale-2',
          )).called(1);

      verifyNever(() => notificationService.showNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          ));
    });

    test('shows an immediate overdue alert when due date is already in the past',
        () async {
      final dueDate = DateTime.now().subtract(const Duration(days: 3));
      final baseId = expectedBaseId('sale-3');

      await service.scheduleDebtReminder(
        saleId: 'sale-3',
        customerName: 'Мария',
        debtAmount: 99.99,
        dueDate: dueDate,
      );

      verifyNever(() => notificationService.scheduleNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            payload: any(named: 'payload'),
          ));

      verify(() => notificationService.showNotification(
            id: baseId + 2,
            title: 'Просроченный долг',
            body: 'Мария: просрочен долг 99.99 сом.',
            payload: 'debt:sale-3',
          )).called(1);
    });

    test(
        'due date exactly at "now" falls through to the overdue branch once real time elapses',
        () async {
      // dueDate is captured slightly before the service's internal
      // DateTime.now() calls execute, so by the time
      // `dueDate.isBefore(DateTime.now())` runs, real wall-clock time has
      // advanced past it — this documents that the three checks are not
      // mutually exclusive around the exact boundary; the overdue branch
      // wins for a "now" due date rather than nothing firing.
      final dueDate = DateTime.now();
      final baseId = expectedBaseId('sale-4');

      await service.scheduleDebtReminder(
        saleId: 'sale-4',
        customerName: 'Олег',
        debtAmount: 10,
        dueDate: dueDate,
      );

      verify(() => notificationService.showNotification(
            id: baseId + 2,
            title: 'Просроченный долг',
            body: 'Олег: просрочен долг 10.00 сом.',
            payload: 'debt:sale-4',
          )).called(1);
    });

    test('formats debt amount to two decimal places even for whole numbers',
        () async {
      final dueDate = DateTime.now().add(const Duration(days: 10));

      await service.scheduleDebtReminder(
        saleId: 'sale-5',
        customerName: 'Настя',
        debtAmount: 200,
        dueDate: dueDate,
      );

      verify(() => notificationService.scheduleNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: 'Настя должен 200.00 сом. Срок оплаты завтра.',
            scheduledDate: any(named: 'scheduledDate'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('derives notification ids deterministically from saleId hash', () async {
      final dueDate = DateTime.now().add(const Duration(days: 5));
      final expected = 'unique-sale-id-42'.hashCode.abs() % 100000;

      await service.scheduleDebtReminder(
        saleId: 'unique-sale-id-42',
        customerName: 'Дилноза',
        debtAmount: 5,
        dueDate: dueDate,
      );

      verify(() => notificationService.scheduleNotification(
            id: expected,
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            payload: any(named: 'payload'),
          )).called(1);
      verify(() => notificationService.scheduleNotification(
            id: expected + 1,
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('DebtReminderService.showLowStockAlert', () {
    test('shows a low-stock notification with a deterministic id and formatted body',
        () async {
      final expectedId = 'Молоко'.hashCode.abs() % 100000 + 50000;

      await service.showLowStockAlert(
        productName: 'Молоко',
        currentQuantity: 3,
      );

      verify(() => notificationService.showNotification(
            id: expectedId,
            title: 'Мало товара на складе',
            body: 'Молоко: осталось 3 шт.',
            payload: 'low_stock:Молоко',
          )).called(1);
    });

    test('produces different ids for different product names', () async {
      await service.showLowStockAlert(productName: 'Хлеб', currentQuantity: 1);
      await service.showLowStockAlert(productName: 'Сахар', currentQuantity: 2);

      final breadId = 'Хлеб'.hashCode.abs() % 100000 + 50000;
      final sugarId = 'Сахар'.hashCode.abs() % 100000 + 50000;

      expect(breadId, isNot(equals(sugarId)));
      verify(() => notificationService.showNotification(
            id: breadId,
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: 'low_stock:Хлеб',
          )).called(1);
      verify(() => notificationService.showNotification(
            id: sugarId,
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: 'low_stock:Сахар',
          )).called(1);
    });

    test('handles zero quantity', () async {
      await service.showLowStockAlert(productName: 'Соль', currentQuantity: 0);

      verify(() => notificationService.showNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: 'Соль: осталось 0 шт.',
            payload: 'low_stock:Соль',
          )).called(1);
    });
  });
}
