import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BannersService } from './banners.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    banner: { findMany: jest.fn(async () => [] as any[]) },
    store: {
      findUnique: jest.fn(async () => ({
        subscription: { plan: 'PREMIUM', status: 'ACTIVE' },
      })),
    },
  };
}

describe('BannersService — getActiveBanner', () => {
  let service: BannersService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [BannersService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(BannersService);
  });

  it('returns null when no banners are active/in-range', async () => {
    (prisma.banner.findMany as jest.Mock).mockResolvedValue([]);
    const result = await service.getActiveBanner('store-1');
    expect(result).toBeNull();
  });

  it('returns the most recently created matching banner when several qualify', async () => {
    (prisma.banner.findMany as jest.Mock).mockResolvedValue([
      { id: 'b-newer', title: 'Newer', createdAt: new Date('2026-07-02') },
      { id: 'b-older', title: 'Older', createdAt: new Date('2026-07-01') },
    ]);
    const result = await service.getActiveBanner('store-1');
    expect(result?.id).toBe('b-newer');
  });

  it('returns null when the store does not exist', async () => {
    (prisma.store.findUnique as jest.Mock).mockResolvedValue(null);
    const result = await service.getActiveBanner('missing-store');
    expect(result).toBeNull();
  });

  it('does not show a plan-targeted banner to a store with no subscription row', async () => {
    (prisma.store.findUnique as jest.Mock).mockResolvedValue({
      subscription: null,
    });
    (prisma.banner.findMany as jest.Mock).mockImplementation(
      async ({ where }: any) => {
        const all = [
          {
            id: 'plan-targeted',
            title: 'Premium only',
            targetPlan: 'PREMIUM',
            createdAt: new Date('2026-07-02'),
          },
          {
            id: 'wildcard',
            title: 'Everyone',
            targetPlan: null,
            createdAt: new Date('2026-07-01'),
          },
        ];
        // Mirror Prisma's OR semantics for the fake so the test actually
        // exercises the query shape, not just the in-memory filter.
        return all.filter((b) =>
          where.OR.some((clause: any) => clause.targetPlan === b.targetPlan),
        );
      },
    );

    const result = await service.getActiveBanner('store-1');

    expect(result?.id).toBe('wildcard');
  });

  it('filters out banners whose targetStatus does not match the store subscription status', async () => {
    (prisma.store.findUnique as jest.Mock).mockResolvedValue({
      subscription: { plan: 'PREMIUM', status: 'ACTIVE' },
    });
    (prisma.banner.findMany as jest.Mock).mockResolvedValue([
      {
        id: 'wrong-status',
        title: 'Trial only',
        targetStatus: 'TRIAL',
        createdAt: new Date('2026-07-02'),
      },
    ]);
    const result = await service.getActiveBanner('store-1');
    expect(result).toBeNull();
  });
});
