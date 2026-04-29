import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, Logger } from '@nestjs/common';
import { OtpType } from '@prisma/client';

import { OtpService } from './otp.service';
import { PrismaService } from '../../prisma/prisma.service';
import { SMS_PROVIDER, SmsProvider } from './sms-provider.interface';

type FakeOtp = {
  id: string;
  phone: string;
  code: string;
  type: OtpType;
  expiresAt: Date;
  used: boolean;
  createdAt: Date;
};

function buildFakePrisma() {
  const otps: FakeOtp[] = [];

  const otpCodeApi = {
    count: jest.fn(async ({ where }: { where: any }) => {
      const since = where.createdAt?.gte as Date | undefined;
      return otps.filter(
        (o) =>
          o.phone === where.phone &&
          o.type === where.type &&
          (!since || o.createdAt >= since),
      ).length;
    }),
    create: jest.fn(async ({ data }: { data: any }) => {
      const row: FakeOtp = {
        id: `otp-${otps.length + 1}`,
        phone: data.phone,
        code: data.code,
        type: data.type,
        expiresAt: data.expiresAt,
        used: false,
        createdAt: new Date(),
      };
      otps.push(row);
      return row;
    }),
    findFirst: jest.fn(async ({ where }: { where: any; orderBy?: any }) => {
      const now = (where.expiresAt?.gte as Date | undefined) ?? new Date();
      const candidates = otps
        .filter(
          (o) =>
            o.phone === where.phone &&
            o.code === where.code &&
            o.type === where.type &&
            o.used === false &&
            o.expiresAt >= now,
        )
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      return candidates[0] ?? null;
    }),
    update: jest.fn(async ({ where, data }: { where: any; data: any }) => {
      const row = otps.find((o) => o.id === where.id);
      if (!row) throw new Error('not found');
      Object.assign(row, data);
      return row;
    }),
  };

  return {
    otpCode: otpCodeApi,
    __otps: otps,
  };
}

describe('OtpService', () => {
  let service: OtpService;
  let prisma: ReturnType<typeof buildFakePrisma>;
  let sms: SmsProvider & { sendSms: jest.Mock };

  beforeEach(async () => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);

    prisma = buildFakePrisma();
    sms = { sendSms: jest.fn(async () => undefined) };

    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: PrismaService, useValue: prisma },
        { provide: SMS_PROVIDER, useValue: sms },
      ],
    }).compile();

    service = moduleRef.get(OtpService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should generate a 6-digit numeric code when sending OTP', async () => {
    await service.sendOtp('+992901234567', OtpType.VERIFY);

    expect(prisma.otpCode.create).toHaveBeenCalledTimes(1);
    const created = (prisma.otpCode.create as jest.Mock).mock.calls[0][0].data;
    expect(created.code).toMatch(/^\d{6}$/);
    expect(sms.sendSms).toHaveBeenCalledWith(
      '+992901234567',
      expect.stringContaining(created.code),
    );
  });

  it('should persist code with ~60s expiry when sending OTP', async () => {
    const before = Date.now();
    await service.sendOtp('+992901234567', OtpType.VERIFY);
    const after = Date.now();

    const created = (prisma.otpCode.create as jest.Mock).mock.calls[0][0].data;
    const expiresAtMs = (created.expiresAt as Date).getTime();
    // Expiry must land in the [now+59s, now+61s] window — sloppy bounds for clock drift in CI.
    expect(expiresAtMs).toBeGreaterThanOrEqual(before + 59_000);
    expect(expiresAtMs).toBeLessThanOrEqual(after + 61_000);
  });

  it('should return true when verifying a matching unused code within expiry', async () => {
    await service.sendOtp('+992901234567', OtpType.VERIFY);
    const code = (prisma.otpCode.create as jest.Mock).mock.calls[0][0].data
      .code as string;

    await expect(
      service.verifyOtp('+992901234567', code, OtpType.VERIFY),
    ).resolves.toBe(true);

    // The matched row is now flagged used so it cannot be replayed.
    expect(prisma.otpCode.update).toHaveBeenCalledTimes(1);
  });

  it('should throw BadRequestException when verifying a non-matching code', async () => {
    await service.sendOtp('+992901234567', OtpType.VERIFY);

    await expect(
      service.verifyOtp('+992901234567', '000000', OtpType.VERIFY),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('should throw BadRequestException when verifying an expired code', async () => {
    await service.sendOtp('+992901234567', OtpType.VERIFY);
    const row = (prisma as any).__otps[0] as FakeOtp;
    // Manually backdate expiry so the code is "expired" without using fake timers.
    row.expiresAt = new Date(Date.now() - 1_000);

    await expect(
      service.verifyOtp('+992901234567', row.code, OtpType.VERIFY),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('should rate-limit when same phone requests OTP more than 3 times in a minute', async () => {
    await service.sendOtp('+992901234567', OtpType.VERIFY);
    await service.sendOtp('+992901234567', OtpType.VERIFY);
    await service.sendOtp('+992901234567', OtpType.VERIFY);

    await expect(
      service.sendOtp('+992901234567', OtpType.VERIFY),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
