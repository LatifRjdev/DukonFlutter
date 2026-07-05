import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { CurrenciesService } from './currencies.service';
import { PrismaService } from '../../prisma/prisma.service';

const MS_DAY = 86_400_000;
const d = (daysAgo: number) => new Date(Date.now() - daysAgo * MS_DAY);

function makePrismaFake() {
  // Seed: two USD rows (today + yesterday) and one RUB row (today)
  // plus a USD row 9 days ago (outside any 7-day window).
  const allRates = [
    { id: 'r1', currency: 'USD', nbtRate: 10.5, buyRate: 10.4, sellRate: 10.6, date: d(0) },
    { id: 'r2', currency: 'USD', nbtRate: 10.4, buyRate: 10.3, sellRate: 10.5, date: d(1) },
    { id: 'r3', currency: 'USD', nbtRate: 10.3, buyRate: 10.2, sellRate: 10.4, date: d(9) },
    { id: 'r4', currency: 'RUB', nbtRate: 0.11, buyRate: 0.109, sellRate: 0.111, date: d(0) },
  ];

  return {
    currencyRate: {
      findMany: jest.fn(async (args: any = {}) => {
        let result = [...allRates];
        const where = args.where ?? {};
        if (where.currency) {
          result = result.filter((r) => r.currency === where.currency);
        }
        if (where.date?.gte) {
          result = result.filter((r) => r.date >= where.date.gte);
        }
        if (args.orderBy?.date === 'asc') {
          result.sort((a, b) => +a.date - +b.date);
        } else if (args.orderBy?.date === 'desc') {
          result.sort((a, b) => +b.date - +a.date);
        }
        if (args.distinct) {
          const seen = new Set<string>();
          result = result.filter((r) => {
            const key = (args.distinct as string[])
              .map((f) => `${f}:${(r as any)[f]}`)
              .join('|');
            if (seen.has(key)) return false;
            seen.add(key);
            return true;
          });
        }
        return result;
      }),
    },
  };
}

describe('CurrenciesService', () => {
  let service: CurrenciesService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        CurrenciesService,
        { provide: PrismaService, useValue: makePrismaFake() },
      ],
    }).compile();
    service = module.get(CurrenciesService);
  });

  describe('getLatestRates', () => {
    it('should return one row per distinct currency (the most recent)', async () => {
      const rates = await service.getLatestRates();

      expect(rates).toHaveLength(2);
      const usd = rates.find((r) => r.currency === 'USD');
      const rub = rates.find((r) => r.currency === 'RUB');
      expect(usd).toBeDefined();
      expect(rub).toBeDefined();
      // Latest USD is r1 (d0, nbtRate=10.5) — not r2 or r3
      expect(Number(usd!.nbtRate)).toBeCloseTo(10.5);
    });
  });

  describe('getRateHistory', () => {
    it('should return ascending history within the requested day window', async () => {
      // 7-day window: r1 (d0) and r2 (d1) qualify; r3 (d9) does not
      const history = await service.getRateHistory('USD', 7);

      expect(history).toHaveLength(2);
      expect(history[0].date <= history[1].date).toBe(true);
      expect(Number(history[0].nbtRate)).toBeCloseTo(10.4);
      expect(Number(history[1].nbtRate)).toBeCloseTo(10.5);
    });

    it('should return an empty array when no rates exist for the given currency', async () => {
      const history = await service.getRateHistory('EUR', 30);
      expect(history).toHaveLength(0);
    });
  });
});
