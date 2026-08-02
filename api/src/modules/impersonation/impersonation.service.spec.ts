import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { ImpersonationService } from './impersonation.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

function makePrismaFake() {
  return {
    impersonationRequest: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'req-1',
        status: 'PENDING',
        ...data,
      })),
      findUnique: jest.fn(async () => null as any),
      findFirst: jest.fn(async () => null as any),
      update: jest.fn(async ({ where, data }: any) => ({
        id: where.id,
        ...data,
      })),
    },
    user: {
      findUnique: jest.fn(async () => ({ id: 'target-1', isAdmin: false })),
      update: jest.fn(async ({ where, data }: any) => ({
        id: where.id,
        ...data,
      })),
    },
    store: { findFirst: jest.fn(async () => ({ id: 'store-1' })) },
    // Fake ops are already-invoked promises by the time $transaction
    // receives them (each mock above resolves eagerly), so this just
    // needs to await the array — matching Prisma's array-form
    // $transaction([...]) API used by end().
    $transaction: jest.fn(async (ops: any[]) => Promise.all(ops)),
  };
}

describe('ImpersonationService', () => {
  let service: ImpersonationService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock };
  let jwt: { sign: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendPush: jest.fn(async () => undefined) };
    jwt = { sign: jest.fn(() => 'signed-token') };
    const config = {
      getOrThrow: jest.fn((key: string) => {
        if (key === 'JWT_ACCESS_SECRET') return 'test-access-secret';
        throw new Error(`Unexpected config key ${key}`);
      }),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        ImpersonationService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: JwtService, useValue: jwt },
        { provide: ConfigService, useValue: config },
      ],
    }).compile();
    service = moduleRef.get(ImpersonationService);
  });

  it('request() creates a PENDING request and notifies the target user', async () => {
    const result = await service.request('admin-1', 'target-1');

    expect(prisma.impersonationRequest.create).toHaveBeenCalledWith({
      data: { adminId: 'admin-1', targetUserId: 'target-1', status: 'PENDING' },
    });
    expect(notifications.sendPush).toHaveBeenCalled();
    expect((result as any).status).toBe('PENDING');
  });

  it('request() throws and never creates a request when the target user is an admin', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'admin-target',
      isAdmin: true,
    });

    await expect(service.request('admin-1', 'admin-target')).rejects.toThrow(
      BadRequestException,
    );
    expect(prisma.impersonationRequest.create).not.toHaveBeenCalled();
    expect(notifications.sendPush).not.toHaveBeenCalled();
  });

  it('respond("APPROVED") sets status, respondedAt, and a 30-minute expiresAt', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
    });

    await service.respond('req-1', 'target-1', 'APPROVED');

    const updateCall = (prisma.impersonationRequest.update as jest.Mock).mock
      .calls[0][0];
    expect(updateCall.data.status).toBe('APPROVED');
    expect(updateCall.data.expiresAt).toBeInstanceOf(Date);
    const minutes =
      (updateCall.data.expiresAt.getTime() -
        updateCall.data.respondedAt.getTime()) /
      60000;
    expect(minutes).toBeCloseTo(30, 0);
  });

  it('respond() throws when the responding user does not own the request', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
    });

    await expect(
      service.respond('req-1', 'someone-else', 'APPROVED'),
    ).rejects.toThrow(BadRequestException);
  });

  it('issueToken() throws when the request is not APPROVED', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 60000),
    });

    await expect(service.issueToken('req-1', 'admin-1')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('issueToken() throws when the approval has expired', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() - 60000),
    });

    await expect(service.issueToken('req-1', 'admin-1')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('issueToken() throws when a different admin than the requester tries to pull the token', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 60000),
    });

    await expect(
      service.issueToken('req-1', 'someone-else-admin'),
    ).rejects.toThrow(ForbiddenException);
    expect(jwt.sign).not.toHaveBeenCalled();
  });

  it('issueToken() signs a JWT carrying impersonatedBy and the impersonation request id', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 60000),
    });

    const token = await service.issueToken('req-1', 'admin-1');

    expect(jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({
        sub: 'target-1',
        impersonatedBy: 'admin-1',
        impersonationRequestId: 'req-1',
      }),
      expect.objectContaining({
        secret: 'test-access-secret',
      }),
    );
    // Payload approved with ~60s left on the approval window — the
    // signed token's own TTL must be clamped to that, not a flat 30m.
    const signOptions = (jwt.sign as jest.Mock).mock.calls[0][1];
    expect(signOptions.expiresIn).toMatch(/^\d+s$/);
    const seconds = parseInt(signOptions.expiresIn, 10);
    expect(seconds).toBeGreaterThan(0);
    expect(seconds).toBeLessThanOrEqual(60);
    expect(token).toBe('signed-token');
  });

  it("issueToken() clamps the JWT's TTL to whatever remains of the approval window instead of a flat 30m — CRITICAL: the 'expires in 30 minutes, in any case' guarantee", async () => {
    // Only ~5 seconds left of the 30-minute approval window (e.g. the
    // admin fetched the token late). A flat '30m' here would silently
    // extend total access to ~30 minutes past this call — nearly double
    // the promised window from the moment the customer approved.
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 5000),
    });

    await service.issueToken('req-1', 'admin-1');

    const signOptions = (jwt.sign as jest.Mock).mock.calls[0][1];
    expect(signOptions.expiresIn).not.toBe('30m');
    expect(signOptions.expiresIn).toMatch(/^\d+s$/);
    const seconds = parseInt(signOptions.expiresIn, 10);
    expect(seconds).toBeGreaterThan(0);
    expect(seconds).toBeLessThanOrEqual(5);
  });

  it('issueToken() never signs a zero-or-negative-TTL token even if expiresAt is a hair in the future', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 1),
    });

    await service.issueToken('req-1', 'admin-1');

    const signOptions = (jwt.sign as jest.Mock).mock.calls[0][1];
    // Math.max(1, ...) floor — never 0s/negative, which some JWT
    // libraries would reject or treat as "already expired".
    expect(signOptions.expiresIn).toBe('1s');
  });

  it("end() marks the request ENDED and bumps the target user's tokensRevokedAt so their live access token is immediately rejected on its next use", async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
    });

    const before = new Date();
    const result = await service.end('req-1');
    const after = new Date();

    expect(prisma.impersonationRequest.update).toHaveBeenCalledWith({
      where: { id: 'req-1' },
      data: { status: 'ENDED', endedAt: expect.any(Date) },
    });

    const userUpdateCall = (prisma.user.update as jest.Mock).mock.calls[0][0];
    expect(userUpdateCall.where).toEqual({ id: 'target-1' });
    expect(userUpdateCall.data.tokensRevokedAt).toBeInstanceOf(Date);
    expect(
      userUpdateCall.data.tokensRevokedAt.getTime(),
    ).toBeGreaterThanOrEqual(before.getTime());
    expect(userUpdateCall.data.tokensRevokedAt.getTime()).toBeLessThanOrEqual(
      after.getTime(),
    );

    expect(prisma.$transaction).toHaveBeenCalled();
    expect((result as any).status).toBe('ENDED');
  });

  it.each(['PENDING', 'REJECTED'])(
    'end() on a %s request throws and does not touch tokensRevokedAt — a request that was never approved never granted access',
    async (status) => {
      (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
        id: 'req-1',
        status,
        adminId: 'admin-1',
        targetUserId: 'target-1',
      });

      await expect(service.end('req-1')).rejects.toThrow(BadRequestException);

      expect(prisma.user.update).not.toHaveBeenCalled();
      expect(prisma.impersonationRequest.update).not.toHaveBeenCalled();
      expect(prisma.$transaction).not.toHaveBeenCalled();
    },
  );

  it('endSelf() revokes when the caller is the target user presenting a token for this exact request', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
    });

    const result = await service.endSelf('req-1', 'target-1', 'req-1');

    const userUpdateCall = (prisma.user.update as jest.Mock).mock.calls[0][0];
    expect(userUpdateCall.where).toEqual({ id: 'target-1' });
    expect(userUpdateCall.data.tokensRevokedAt).toBeInstanceOf(Date);
    expect((result as any).status).toBe('ENDED');
  });

  it("endSelf() throws and revokes nothing when the caller is not the request's target user", async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
    });

    await expect(
      service.endSelf('req-1', 'someone-else', 'req-1'),
    ).rejects.toThrow(ForbiddenException);
    expect(prisma.user.update).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it("endSelf() throws when the presented token's impersonationRequestId claim does not match the request being ended", async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
    });

    await expect(
      service.endSelf('req-1', 'target-1', 'some-other-request-id'),
    ).rejects.toThrow(ForbiddenException);
    expect(prisma.user.update).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('endSelf() throws when the request was never approved', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      adminId: 'admin-1',
      targetUserId: 'target-1',
    });

    await expect(service.endSelf('req-1', 'target-1', 'req-1')).rejects.toThrow(
      BadRequestException,
    );
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('findPendingForUser() looks up the most recent PENDING request scoped to that user', async () => {
    (prisma.impersonationRequest.findFirst as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
    });

    const result = await service.findPendingForUser('target-1');

    expect(prisma.impersonationRequest.findFirst).toHaveBeenCalledWith({
      where: { targetUserId: 'target-1', status: 'PENDING' },
      orderBy: { requestedAt: 'desc' },
    });
    expect((result as any).id).toBe('req-1');
  });
});
