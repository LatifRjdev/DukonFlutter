import { Test, TestingModule } from '@nestjs/testing';
import {
  ConflictException,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';

import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { PrismaService } from '../../prisma/prisma.service';

// In-memory fakes — we test behavior, not Prisma internals (per .claude/rules/testing.md).
type FakeUser = {
  id: string;
  phone: string;
  password: string;
  name: string;
  email: string | null;
  isActive: boolean;
  isAdmin: boolean;
};

type FakeRefreshToken = {
  id: string;
  token: string;
  userId: string;
  expiresAt: Date;
};

function buildFakePrisma() {
  const users: FakeUser[] = [];
  const refreshTokens: FakeRefreshToken[] = [];

  const userApi = {
    findUnique: jest.fn(async ({ where }: { where: any }) => {
      if (where.phone) {
        return users.find((u) => u.phone === where.phone) ?? null;
      }
      if (where.id) {
        const u = users.find((u) => u.id === where.id) ?? null;
        return u ? { isAdmin: u.isAdmin } : null;
      }
      return null;
    }),
    create: jest.fn(async ({ data }: { data: any }) => {
      const user: FakeUser = {
        id: data.id ?? `user-${users.length + 1}`,
        phone: data.phone,
        password: data.password,
        name: data.name,
        email: data.email ?? null,
        isActive: data.isActive ?? true,
        isAdmin: data.isAdmin ?? false,
      };
      users.push(user);
      return user;
    }),
    update: jest.fn(async ({ where, data }: { where: any; data: any }) => {
      const u = users.find((u) => u.phone === where.phone);
      if (!u) throw new Error('User not found');
      Object.assign(u, data);
      return u;
    }),
  };

  const refreshTokenApi = {
    create: jest.fn(async ({ data }: { data: any }) => {
      const row: FakeRefreshToken = {
        id: `rt-${refreshTokens.length + 1}`,
        token: data.token,
        userId: data.userId,
        expiresAt: data.expiresAt,
      };
      refreshTokens.push(row);
      return row;
    }),
    deleteMany: jest.fn(async ({ where }: { where: any }) => {
      const before = refreshTokens.length;
      for (let i = refreshTokens.length - 1; i >= 0; i--) {
        const r = refreshTokens[i];
        const matchesToken =
          where.token === undefined || r.token === where.token;
        const matchesUser =
          where.userId === undefined || r.userId === where.userId;
        if (matchesToken && matchesUser) {
          refreshTokens.splice(i, 1);
        }
      }
      return { count: before - refreshTokens.length };
    }),
  };

  // Prisma transaction client matches the same shape used in service.
  const txClient = {
    user: userApi,
    refreshToken: refreshTokenApi,
  };

  const prisma: any = {
    user: userApi,
    refreshToken: refreshTokenApi,
    $transaction: jest.fn(async (cb: (tx: any) => Promise<any>) => cb(txClient)),
  };

  // Test-only handles for assertions:
  prisma.__users = users;
  prisma.__refreshTokens = refreshTokens;

  return prisma;
}

function buildFakeJwt() {
  const payloads: any[] = [];
  const jwt = {
    signAsync: jest.fn(async (payload: any, opts: any) => {
      payloads.push({ payload, opts });
      // Encode payload + secret hint so tests can introspect.
      return `jwt.${Buffer.from(JSON.stringify(payload)).toString('base64')}.${opts?.expiresIn ?? ''}`;
    }),
  } as unknown as JwtService & { __payloads: any[] };
  (jwt as any).__payloads = payloads;
  return jwt;
}

function buildFakeConfig() {
  return {
    getOrThrow: jest.fn((key: string) => {
      if (key === 'JWT_ACCESS_SECRET') return 'access-secret';
      if (key === 'JWT_REFRESH_SECRET') return 'refresh-secret';
      throw new Error(`unexpected key ${key}`);
    }),
  } as unknown as ConfigService;
}

function decodeAccessPayload(token: string) {
  const b64 = token.split('.')[1];
  return JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
}

describe('AuthService', () => {
  let service: AuthService;
  let prisma: ReturnType<typeof buildFakePrisma>;
  let jwt: ReturnType<typeof buildFakeJwt>;

  const validRegisterDto = {
    name: 'Ali Rahimov',
    phone: '+992901234567',
    password: 'CorrectHorseBatteryStaple8',
    email: 'ali@example.com',
  };

  beforeEach(async () => {
    // Suppress Logger noise per task convention.
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);

    prisma = buildFakePrisma();
    jwt = buildFakeJwt();

    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
        { provide: ConfigService, useValue: buildFakeConfig() },
        {
          provide: OtpService,
          useValue: {
            sendOtp: jest.fn(),
            verifyOtp: jest.fn(),
          },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('register', () => {
    it('should create user with bcrypt-hashed password when phone is new', async () => {
      const result = await service.register(validRegisterDto);

      expect(prisma.user.create).toHaveBeenCalledTimes(1);
      const createArg = (prisma.user.create as jest.Mock).mock.calls[0][0];
      // password persisted is hashed, never the plain value
      expect(createArg.data.password).not.toBe(validRegisterDto.password);
      // bcrypt hash starts with $2 and verifies back to the plain password
      expect(createArg.data.password.startsWith('$2')).toBe(true);
      const matches = await bcrypt.compare(
        validRegisterDto.password,
        createArg.data.password,
      );
      expect(matches).toBe(true);
      expect(result.user.phone).toBe(validRegisterDto.phone);
    });

    it('should throw ConflictException when phone is already registered', async () => {
      await service.register(validRegisterDto);

      await expect(service.register(validRegisterDto)).rejects.toBeInstanceOf(
        ConflictException,
      );
    });

    it('should return access and refresh tokens when registration succeeds', async () => {
      const result = await service.register(validRegisterDto);

      expect(typeof result.accessToken).toBe('string');
      expect(typeof result.refreshToken).toBe('string');
      expect(result.accessToken.length).toBeGreaterThan(0);
      expect(result.refreshToken.length).toBeGreaterThan(0);
      // refresh row persisted
      expect(prisma.refreshToken.create).toHaveBeenCalledTimes(1);
    });
  });

  describe('login', () => {
    beforeEach(async () => {
      await service.register(validRegisterDto);
    });

    it('should succeed when phone and password are valid', async () => {
      const result = await service.login({
        phone: validRegisterDto.phone,
        password: validRegisterDto.password,
      });

      expect(result.user.phone).toBe(validRegisterDto.phone);
      expect(typeof result.accessToken).toBe('string');
    });

    it('should throw UnauthorizedException when password is wrong', async () => {
      await expect(
        service.login({
          phone: validRegisterDto.phone,
          password: 'WrongPassword123',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('should throw UnauthorizedException when phone is not registered', async () => {
      await expect(
        service.login({
          phone: '+992900000000',
          password: validRegisterDto.password,
        }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('should include isAdmin in response user payload', async () => {
      const result = await service.login({
        phone: validRegisterDto.phone,
        password: validRegisterDto.password,
      });

      expect(result.user).toHaveProperty('isAdmin');
      expect(typeof result.user.isAdmin).toBe('boolean');
      expect(result.user.isAdmin).toBe(false);
    });
  });

  describe('generateTokens (via register)', () => {
    it('should embed sub, phone and isAdmin claim in the access JWT payload', async () => {
      const result = await service.register(validRegisterDto);
      const payload = decodeAccessPayload(result.accessToken);

      expect(payload).toMatchObject({
        sub: expect.any(String),
        phone: validRegisterDto.phone,
        isAdmin: false,
      });

      // Ensure jwtService.signAsync was called twice (access + refresh)
      // with the right secrets.
      expect(jwt.signAsync).toHaveBeenCalledTimes(2);
      const calls = (jwt.signAsync as jest.Mock).mock.calls;
      const secrets = calls.map((c) => c[1].secret).sort();
      expect(secrets).toEqual(['access-secret', 'refresh-secret']);
    });
  });

  describe('refresh', () => {
    let userId: string;
    let phone: string;
    let originalJti: string;

    beforeEach(async () => {
      const reg = await service.register(validRegisterDto);
      userId = (prisma as any).__users[0].id;
      phone = validRegisterDto.phone;
      // The persisted jti is the token row inserted at register time.
      originalJti = (prisma as any).__refreshTokens[0].token;
      // Sanity: register only used the `signAsync` calls, clear for isolation.
      (jwt.signAsync as jest.Mock).mockClear();
      void reg;
    });

    it('should rotate refresh token (old row deleted, new row inserted) when valid', async () => {
      const before = (prisma as any).__refreshTokens.map(
        (r: FakeRefreshToken) => r.token,
      );
      expect(before).toContain(originalJti);

      const result = await service.refresh(userId, phone, originalJti);

      const after = (prisma as any).__refreshTokens.map(
        (r: FakeRefreshToken) => r.token,
      );
      expect(after).not.toContain(originalJti); // old revoked
      expect(after.length).toBe(1); // exactly one active row
      expect(typeof result.accessToken).toBe('string');
      expect(typeof result.refreshToken).toBe('string');
    });

    it('should throw UnauthorizedException when refresh token is unknown', async () => {
      await expect(
        service.refresh(userId, phone, 'never-issued-jti'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('should detect replay (same token used twice) and revoke all user tokens', async () => {
      // First use rotates successfully and persists a brand-new row.
      await service.refresh(userId, phone, originalJti);
      expect((prisma as any).__refreshTokens.length).toBe(1);

      // Second use of the SAME old jti must:
      //  (a) throw UnauthorizedException, and
      //  (b) wipe every refresh token for the user.
      await expect(
        service.refresh(userId, phone, originalJti),
      ).rejects.toBeInstanceOf(UnauthorizedException);

      expect((prisma as any).__refreshTokens.length).toBe(0);
    });
  });

  describe('logout', () => {
    it('should revoke a specific refresh token by jti when provided', async () => {
      await service.register(validRegisterDto);
      const userId = (prisma as any).__users[0].id;
      const jti = (prisma as any).__refreshTokens[0].token;

      await service.logout(userId, jti);

      expect((prisma as any).__refreshTokens.length).toBe(0);
      expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({
        where: { token: jti, userId },
      });
    });
  });
});
