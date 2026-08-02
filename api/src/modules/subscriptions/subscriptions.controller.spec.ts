import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { AdminSubscriptionsController } from './subscriptions.controller';
import { SubscriptionsService } from './subscriptions.service';
import { AdminExportService } from '../admin/admin-export.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { INTERCEPTORS_METADATA } from '@nestjs/common/constants';

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

    const fakeExportService = {
      exportSubscriptions: jest.fn(async () => Buffer.from('')),
    };

    const moduleRef = await Test.createTestingModule({
      controllers: [AdminSubscriptionsController],
      providers: [
        { provide: SubscriptionsService, useValue: fakeService },
        { provide: AdminExportService, useValue: fakeExportService },
        // AdminSubscriptionsController now carries
        // @UseInterceptors(AuditInterceptor) (see the audit-trail-integrity
        // fix that wired it up alongside every other Admin*Controller) —
        // Nest resolves classes referenced by @UseInterceptors through the
        // module's DI container even in a controller-only testing module,
        // so AuditInterceptor's own dependency (PrismaService) must be
        // satisfiable here too, or module compilation fails.
        { provide: PrismaService, useValue: {} },
      ],
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

// This branch's whole-branch review flagged that AdminSubscriptionsController
// — including the financially-sensitive manual-payment endpoint (an
// admin-typed amount, capped at 50,000 TJS, that directly extends paid
// access) — had no audit-diff coverage at all, unlike every other
// Admin*Controller. AuditInterceptor's own before/after-diff behavior is
// generic and already covered exhaustively in
// common/interceptors/audit.interceptor.spec.ts, so this just confirms the
// controller is actually wired up to it (the missing piece).
describe('AdminSubscriptionsController — AuditInterceptor wiring', () => {
  it('carries @UseInterceptors(AuditInterceptor) at the class level', () => {
    const interceptors = Reflect.getMetadata(
      INTERCEPTORS_METADATA,
      AdminSubscriptionsController,
    );
    expect(interceptors).toContain(AuditInterceptor);
  });
});
