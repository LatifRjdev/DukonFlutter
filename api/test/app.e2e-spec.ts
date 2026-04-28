/**
 * Auth + health happy-path E2E for the NestJS API.
 *
 * Boots a focused test app composed of just the modules we exercise
 * (Auth + Health) to keep the test runnable on a developer machine
 * with no Postgres / Redis / SMS provider available. PrismaService is
 * overridden with a Map-backed in-memory fake — same pattern as the
 * unit tests under `src/modules/admin/admin.payments.spec.ts`. The
 * Terminus PrismaHealthIndicator is also stubbed so /api/health doesn't
 * try to ping a real DB.
 *
 * Coverage:
 *   1. POST /api/auth/register  -> 201 + tokens (happy path)
 *   2. POST /api/auth/register  -> 409 on duplicate phone
 *   3. POST /api/auth/login     -> 200 + tokens (happy path)
 *   4. POST /api/auth/login     -> 401 on wrong password
 *   5. POST /api/auth/refresh   -> 200 + new tokens; old refresh stops working
 *   6. GET  /api/health         -> 200 with status:ok
 */
import 'reflect-metadata';

// Provide JWT secrets BEFORE any module imports — the bootstrap config
// validator + JwtAccessStrategy / JwtRefreshStrategy read these eagerly.
process.env.JWT_ACCESS_SECRET =
  process.env.JWT_ACCESS_SECRET ||
  'e2e-test-access-secret-must-be-at-least-32-characters-long-yes';
process.env.JWT_REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET ||
  'e2e-test-refresh-secret-must-be-at-least-32-characters-long-ok';
process.env.NODE_ENV = process.env.NODE_ENV || 'test';

import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import {
  HealthCheckService,
  PrismaHealthIndicator,
  TerminusModule,
} from '@nestjs/terminus';
import request from 'supertest';

import { AuthModule } from '../src/modules/auth/auth.module';
import { HealthController } from '../src/modules/health/health.controller';
import { PrismaModule } from '../src/prisma/prisma.module';
import { PrismaService } from '../src/prisma/prisma.service';

// ---------------------------------------------------------------------------
// Map-backed Prisma fake. Implements just the surface area auth + refresh +
// access strategy hit during this suite: user, refreshToken, otpCode, and a
// $transaction(callback) that re-uses `this` as the tx client.
// ---------------------------------------------------------------------------
type FakeUser = {
  id: string;
  phone: string;
  password: string;
  name: string;
  email: string | null;
  isAdmin: boolean;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
};
type FakeRefreshToken = {
  id: string;
  token: string;
  userId: string;
  expiresAt: Date;
  createdAt: Date;
};

function makePrismaFake() {
  const usersById = new Map<string, FakeUser>();
  const usersByPhone = new Map<string, FakeUser>();
  const refreshTokens = new Map<string, FakeRefreshToken>();
  let userSeq = 0;
  let rtSeq = 0;

  const userDelegate = {
    findUnique: jest.fn(async ({ where }: any) => {
      if (where?.phone) return usersByPhone.get(where.phone) ?? null;
      if (where?.id) return usersById.get(where.id) ?? null;
      return null;
    }),
    create: jest.fn(async ({ data }: any) => {
      userSeq += 1;
      const now = new Date();
      const u: FakeUser = {
        id: `user-${userSeq}`,
        phone: data.phone,
        password: data.password,
        name: data.name,
        email: data.email ?? null,
        isAdmin: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      };
      usersById.set(u.id, u);
      usersByPhone.set(u.phone, u);
      return { ...u };
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const u =
        (where?.id && usersById.get(where.id)) ||
        (where?.phone && usersByPhone.get(where.phone));
      if (!u) throw new Error('user not found');
      Object.assign(u, data, { updatedAt: new Date() });
      return { ...u };
    }),
  };

  const refreshTokenDelegate = {
    create: jest.fn(async ({ data }: any) => {
      rtSeq += 1;
      const row: FakeRefreshToken = {
        id: `rt-${rtSeq}`,
        token: data.token,
        userId: data.userId,
        expiresAt: data.expiresAt,
        createdAt: new Date(),
      };
      refreshTokens.set(row.id, row);
      return { ...row };
    }),
    findFirst: jest.fn(async ({ where }: any) => {
      for (const row of refreshTokens.values()) {
        if (where?.userId && row.userId !== where.userId) continue;
        if (where?.token && row.token !== where.token) continue;
        return { ...row };
      }
      return null;
    }),
    deleteMany: jest.fn(async ({ where }: any) => {
      let count = 0;
      for (const [id, row] of refreshTokens) {
        if (where?.userId && row.userId !== where.userId) continue;
        if (where?.token && row.token !== where.token) continue;
        refreshTokens.delete(id);
        count += 1;
      }
      return { count };
    }),
  };

  const otpCodeDelegate = {
    count: jest.fn(async () => 0),
    create: jest.fn(async () => ({})),
    findFirst: jest.fn(async () => null),
    update: jest.fn(async () => ({})),
  };

  const fake: any = {
    user: userDelegate,
    refreshToken: refreshTokenDelegate,
    otpCode: otpCodeDelegate,
    // The refresh path does prisma.$transaction(async (tx) => ...). The
    // service only calls tx.refreshToken.* and tx.user.findUnique, so
    // re-using `fake` itself as the tx client is sufficient.
    $transaction: jest.fn(async (arg: any) => {
      if (typeof arg === 'function') return arg(fake);
      return Promise.all(arg);
    }),
    // Hooks Nest expects on PrismaService — make them no-ops.
    onModuleInit: jest.fn(async () => undefined),
    onModuleDestroy: jest.fn(async () => undefined),
    $connect: jest.fn(async () => undefined),
    $disconnect: jest.fn(async () => undefined),
    // Internal accessors for assertions if needed.
    _users: usersById,
    _refreshTokens: refreshTokens,
  };

  return fake;
}

describe('Auth + Health (e2e)', () => {
  let app: INestApplication;
  let prismaFake: ReturnType<typeof makePrismaFake>;

  const REGISTER_PAYLOAD = {
    name: 'Ali Test',
    phone: '+992901112233',
    password: 'CorrectHorseBattery8',
  };

  beforeAll(async () => {
    prismaFake = makePrismaFake();

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({ isGlobal: true, ignoreEnvFile: true }),
        TerminusModule,
        PrismaModule,
        AuthModule,
      ],
      controllers: [HealthController],
    })
      .overrideProvider(PrismaService)
      .useValue(prismaFake)
      .overrideProvider(PrismaHealthIndicator)
      .useValue({
        pingCheck: jest.fn(async () => ({ database: { status: 'up' } })),
      })
      .overrideProvider(HealthCheckService)
      .useValue({
        check: async (indicators: Array<() => Promise<any>>) => {
          const details: Record<string, any> = {};
          for (const fn of indicators) Object.assign(details, await fn());
          return { status: 'ok', info: details, error: {}, details };
        },
      })
      .compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  it('POST /api/auth/register returns 201 + access/refresh tokens and a user payload', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send(REGISTER_PAYLOAD)
      .expect(201);

    expect(res.body.accessToken).toEqual(expect.any(String));
    expect(res.body.refreshToken).toEqual(expect.any(String));
    expect(res.body.user).toEqual(
      expect.objectContaining({
        phone: REGISTER_PAYLOAD.phone,
        name: REGISTER_PAYLOAD.name,
        isAdmin: false,
      }),
    );
    expect(res.body.user.password).toBeUndefined();
  });

  it('POST /api/auth/register returns 409 when the phone is already registered', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send(REGISTER_PAYLOAD)
      .expect(409);

    expect(JSON.stringify(res.body)).toMatch(/already exists/i);
  });

  it('POST /api/auth/login returns 200 + tokens for correct credentials', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        phone: REGISTER_PAYLOAD.phone,
        password: REGISTER_PAYLOAD.password,
      })
      .expect(200);

    expect(res.body.accessToken).toEqual(expect.any(String));
    expect(res.body.refreshToken).toEqual(expect.any(String));
    expect(res.body.user.phone).toBe(REGISTER_PAYLOAD.phone);
  });

  it('POST /api/auth/login returns 401 on wrong password', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ phone: REGISTER_PAYLOAD.phone, password: 'WrongPassword9' })
      .expect(401);
  });

  it('POST /api/auth/refresh rotates tokens and the old refresh token stops working', async () => {
    // Grab a fresh refresh token via login so the rotation test is independent.
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        phone: REGISTER_PAYLOAD.phone,
        password: REGISTER_PAYLOAD.password,
      })
      .expect(200);
    const oldRefresh: string = login.body.refreshToken;

    const rotated = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: oldRefresh })
      .expect(200);

    expect(rotated.body.accessToken).toEqual(expect.any(String));
    expect(rotated.body.refreshToken).toEqual(expect.any(String));
    expect(rotated.body.refreshToken).not.toBe(oldRefresh);

    // Reusing the old refresh token must now fail (replay detection).
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: oldRefresh })
      .expect(401);
  });

  it('GET /api/health returns 200 with status:ok', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/health')
      .expect(200);

    expect(res.body.status).toBe('ok');
    expect(res.body.details?.database?.status).toBe('up');
  });
});
