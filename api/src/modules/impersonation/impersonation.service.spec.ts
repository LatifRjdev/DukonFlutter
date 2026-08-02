import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
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
      update: jest.fn(async ({ where, data }: any) => ({
        id: where.id,
        ...data,
      })),
    },
    user: { findUnique: jest.fn(async () => ({ id: 'target-1' })) },
    store: { findFirst: jest.fn(async () => ({ id: 'store-1' })) },
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

    await expect(service.issueToken('req-1')).rejects.toThrow(
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

    await expect(service.issueToken('req-1')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('issueToken() signs a JWT carrying impersonatedBy and the impersonation request id', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 60000),
    });

    const token = await service.issueToken('req-1');

    expect(jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({
        sub: 'target-1',
        impersonatedBy: 'admin-1',
        impersonationRequestId: 'req-1',
      }),
      expect.objectContaining({
        expiresIn: '30m',
        secret: 'test-access-secret',
      }),
    );
    expect(token).toBe('signed-token');
  });
});
