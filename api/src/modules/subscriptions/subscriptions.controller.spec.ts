import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { AdminSubscriptionsController } from './subscriptions.controller';
import { SubscriptionsService } from './subscriptions.service';

// We mock the service to a bare object — the controller is a thin
// delegator, so we only care that the two manual-trigger endpoints
// call the matching service methods and surface { ok: true }.
//
// Context: F-3 from the 2026-05-07 deep QA pass — @Cron('0 0 * * *')
// (checkExpiredSubscriptions) and @Cron('0 9 * * *') (sendExpiryReminders)
// had no manual trigger, so QA had to wait for midnight to exercise the
// EXPIRED-state flip + FCM push path. These tests lock in the new admin
// POST endpoints that expose the cron methods on demand.
describe('AdminSubscriptionsController — manual cron triggers (F-3)', () => {
  let controller: AdminSubscriptionsController;
  let service: SubscriptionsService;

  beforeEach(async () => {
    const fakeService = {
      checkExpiredSubscriptions: jest.fn(async () => undefined),
      sendExpiryReminders: jest.fn(async () => undefined),
    };

    const moduleRef = await Test.createTestingModule({
      controllers: [AdminSubscriptionsController],
      providers: [{ provide: SubscriptionsService, useValue: fakeService }],
    }).compile();

    controller = moduleRef.get(AdminSubscriptionsController);
    service = moduleRef.get(SubscriptionsService);
  });

  it('runExpiryCheck should delegate to service.checkExpiredSubscriptions when called', async () => {
    const spy = jest.spyOn(service, 'checkExpiredSubscriptions');

    const res = await controller.runExpiryCheck();

    expect(spy).toHaveBeenCalledTimes(1);
    expect(res.ok).toBe(true);
    expect(res.message).toMatch(/expiry check/i);
  });

  it('sendExpiryReminders should delegate to service.sendExpiryReminders when called', async () => {
    const spy = jest.spyOn(service, 'sendExpiryReminders');

    const res = await controller.sendExpiryReminders();

    expect(spy).toHaveBeenCalledTimes(1);
    expect(res.ok).toBe(true);
    expect(res.message).toMatch(/reminders/i);
  });
});
