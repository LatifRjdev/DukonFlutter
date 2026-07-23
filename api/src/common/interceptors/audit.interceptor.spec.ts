import 'reflect-metadata';
import { firstValueFrom, of } from 'rxjs';
import { CallHandler, ExecutionContext } from '@nestjs/common';
import { AuditInterceptor } from './audit.interceptor';
import { PrismaService } from '../../prisma/prisma.service';

function makeContext(opts: {
  method: string;
  url: string;
  body?: Record<string, unknown>;
  routePath?: string;
  userId?: string;
}): ExecutionContext {
  const request = {
    method: opts.method,
    url: opts.url,
    body: opts.body,
    route: { path: opts.routePath ?? opts.url },
    params: {},
    user: opts.userId ? { id: opts.userId } : undefined,
    headers: {},
  };
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

function makeCallHandler(): CallHandler {
  return { handle: () => of({ ok: true }) };
}

describe('AuditInterceptor — sensitive field redaction', () => {
  let prisma: { auditLog: { create: jest.Mock } };
  let interceptor: AuditInterceptor;

  beforeEach(() => {
    prisma = { auditLog: { create: jest.fn(async () => ({})) } };
    interceptor = new AuditInterceptor(prisma as unknown as PrismaService);
  });

  it('should redact a password field before writing to the audit log', async () => {
    const ctx = makeContext({
      method: 'POST',
      url: '/admin/users',
      routePath: '/admin/users',
      userId: 'admin-1',
      body: { name: 'Али', phone: '+992901234567', password: 'SuperSecret123' },
    });

    await firstValueFrom(interceptor.intercept(ctx, makeCallHandler()));

    const call = prisma.auditLog.create.mock.calls[0][0];
    expect(call.data.details.password).toBe('[REDACTED]');
    expect(call.data.details.name).toBe('Али');
    expect(call.data.details.phone).toBe('+992901234567');
  });

  it('should redact a newPassword field before writing to the audit log', async () => {
    const ctx = makeContext({
      method: 'PATCH',
      url: '/admin/users/u1/password',
      routePath: '/admin/users/:id/password',
      userId: 'admin-1',
      body: { newPassword: 'AnotherSecret456' },
    });

    await firstValueFrom(interceptor.intercept(ctx, makeCallHandler()));

    const call = prisma.auditLog.create.mock.calls[0][0];
    expect(call.data.details.newPassword).toBe('[REDACTED]');
  });

  it('should leave a body with no sensitive fields untouched', async () => {
    const ctx = makeContext({
      method: 'PUT',
      url: '/admin/subscriptions/sub-1/extend',
      routePath: '/admin/subscriptions/:id/extend',
      userId: 'admin-1',
      body: { days: 30 },
    });

    await firstValueFrom(interceptor.intercept(ctx, makeCallHandler()));

    const call = prisma.auditLog.create.mock.calls[0][0];
    expect(call.data.details).toEqual({ days: 30 });
  });

  it('should pass through a null body unchanged', async () => {
    const ctx = makeContext({
      method: 'DELETE',
      url: '/admin/users/u1',
      routePath: '/admin/users/:id',
      userId: 'admin-1',
    });

    await firstValueFrom(interceptor.intercept(ctx, makeCallHandler()));

    const call = prisma.auditLog.create.mock.calls[0][0];
    expect(call.data.details).toBeNull();
  });
});
