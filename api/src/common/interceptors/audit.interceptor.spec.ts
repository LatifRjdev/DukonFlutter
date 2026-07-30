import 'reflect-metadata';
import { of } from 'rxjs';
import { AuditInterceptor } from './audit.interceptor';
import { PrismaService } from '../../prisma/prisma.service';
import { CallHandler, ExecutionContext } from '@nestjs/common';

function makeContext(overrides: {
  method: string;
  url: string;
  routePath?: string;
  params?: Record<string, string>;
  body?: any;
  user?: { id: string };
}): ExecutionContext {
  const request = {
    method: overrides.method,
    url: overrides.url,
    route: { path: overrides.routePath ?? overrides.url },
    params: overrides.params ?? {},
    body: overrides.body ?? {},
    user: overrides.user,
    ip: '127.0.0.1',
    headers: {},
  };
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as any;
}

function makeCallHandler(response: any): CallHandler {
  return { handle: () => of(response) };
}

describe('AuditInterceptor — before/after diff', () => {
  let prisma: {
    user: any;
    subscriptionPlanConfig: any;
    auditLog: { create: jest.Mock };
  };
  let interceptor: AuditInterceptor;

  beforeEach(() => {
    prisma = {
      user: { findUnique: jest.fn() },
      subscriptionPlanConfig: { findUnique: jest.fn() },
      auditLog: { create: jest.fn(async () => undefined) },
    };
    interceptor = new AuditInterceptor(prisma as unknown as PrismaService);
  });

  it('captures before and after snapshots for an UPDATE on a known entity', (done) => {
    (prisma.user.findUnique as jest.Mock)
      .mockResolvedValueOnce({ id: 'u1', isAdmin: false })
      .mockResolvedValueOnce({ id: 'u1', isAdmin: true });

    const context = makeContext({
      method: 'PUT',
      url: '/admin/users/u1/toggle-admin',
      routePath: '/admin/users/:id/toggle-admin',
      params: { id: 'u1' },
      user: { id: 'admin-1' },
    });

    interceptor
      .intercept(context, makeCallHandler({ id: 'u1', isAdmin: true }))
      .subscribe({
        complete: () => {
          setImmediate(() => {
            expect(prisma.auditLog.create).toHaveBeenCalledWith(
              expect.objectContaining({
                data: expect.objectContaining({
                  details: {
                    before: { id: 'u1', isAdmin: false },
                    after: { id: 'u1', isAdmin: true },
                  },
                }),
              }),
            );
            done();
          });
        },
      });
  });

  it('uses the plan config pkField "plan" (not "id") when capturing subscription-plan snapshots', (done) => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock)
      .mockResolvedValueOnce({ plan: 'START', maxProducts: 500 })
      .mockResolvedValueOnce({ plan: 'START', maxProducts: 600 });

    const context = makeContext({
      method: 'PUT',
      url: '/admin/plans/START',
      routePath: '/admin/plans/:plan',
      params: { plan: 'START' },
      user: { id: 'admin-1' },
    });

    interceptor
      .intercept(context, makeCallHandler({ plan: 'START', maxProducts: 600 }))
      .subscribe({
        complete: () => {
          setImmediate(() => {
            expect(
              prisma.subscriptionPlanConfig.findUnique,
            ).toHaveBeenCalledWith({
              where: { plan: 'START' },
            });
            expect(prisma.auditLog.create).toHaveBeenCalledWith(
              expect.objectContaining({
                data: expect.objectContaining({
                  details: {
                    before: { plan: 'START', maxProducts: 500 },
                    after: { plan: 'START', maxProducts: 600 },
                  },
                }),
              }),
            );
            done();
          });
        },
      });
  });

  it('falls back to the response body as "after" (and null "before") for CREATE routes with no entityId', (done) => {
    const context = makeContext({
      method: 'POST',
      url: '/admin/users',
      routePath: '/admin/users',
      params: {},
      body: { name: 'Новый', phone: '+992900000009' },
      user: { id: 'admin-1' },
    });

    const responseBody = { id: 'u-new', name: 'Новый' };

    interceptor.intercept(context, makeCallHandler(responseBody)).subscribe({
      complete: () => {
        setImmediate(() => {
          expect(prisma.auditLog.create).toHaveBeenCalledWith(
            expect.objectContaining({
              data: expect.objectContaining({
                details: {
                  before: null,
                  after: responseBody,
                },
              }),
            }),
          );
          done();
        });
      },
    });
  });

  it('redacts sensitive fields inside both before and after', (done) => {
    (prisma.user.findUnique as jest.Mock)
      .mockResolvedValueOnce({ id: 'u1', password: 'old-hash' })
      .mockResolvedValueOnce({ id: 'u1', password: 'new-hash' });

    const context = makeContext({
      method: 'PUT',
      url: '/admin/users/u1/block',
      routePath: '/admin/users/:id/block',
      params: { id: 'u1' },
      user: { id: 'admin-1' },
    });

    interceptor.intercept(context, makeCallHandler({ id: 'u1' })).subscribe({
      complete: () => {
        setImmediate(() => {
          const call = (prisma.auditLog.create as jest.Mock).mock.calls[0][0];
          expect(call.data.details.before.password).toBe('[REDACTED]');
          expect(call.data.details.after.password).toBe('[REDACTED]');
          done();
        });
      },
    });
  });
});
