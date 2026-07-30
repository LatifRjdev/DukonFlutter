import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import * as ExcelJS from 'exceljs';
import { AdminExportService } from './admin-export.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    user: {
      findMany: jest.fn(async () => [
        {
          id: 'u1',
          name: 'Алишер',
          phone: '+992900000001',
          email: null,
          isAdmin: false,
          isActive: true,
          createdAt: new Date('2026-01-01'),
        },
      ]),
    },
    store: {
      findMany: jest.fn(async () => [
        {
          name: 'Bozor Plus',
          category: 'GROCERY',
          isActive: true,
          createdAt: new Date('2026-01-02'),
          owner: { name: 'Фарход', phone: '+992900000002' },
          subscription: { plan: 'BUSINESS', status: 'ACTIVE' },
        },
      ]),
    },
    subscription: {
      findMany: jest.fn(async () => [
        {
          plan: 'PREMIUM',
          status: 'TRIAL',
          currentPeriodStart: new Date('2026-01-01'),
          currentPeriodEnd: new Date('2026-02-01'),
          createdAt: new Date('2026-01-01'),
          store: {
            name: 'Bozor Plus',
            owner: { name: 'Фарход', phone: '+992900000002' },
          },
        },
      ]),
    },
  };
}

describe('AdminExportService', () => {
  let service: AdminExportService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminExportService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(AdminExportService);
  });

  it('exportUsers produces an xlsx buffer with one row per user, honoring the search filter', async () => {
    const buffer = await service.exportUsers({ search: 'Алишер' } as any);

    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'Алишер', mode: 'insensitive' } },
          ]),
        }),
      }),
    );

    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(buffer as any);
    const ws = wb.getWorksheet('Users');
    expect(ws?.rowCount).toBe(2); // header + 1 data row
    expect(ws?.getRow(2).getCell(1).value).toBe('Алишер');
  });

  it('exportStores produces an xlsx buffer with one row per store, honoring search/plan filters', async () => {
    const buffer = await service.exportStores({
      search: 'Фарход',
      plan: 'BUSINESS',
    } as any);

    expect(prisma.store.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'Фарход', mode: 'insensitive' } },
            {
              owner: { name: { contains: 'Фарход', mode: 'insensitive' } },
            },
          ]),
          subscription: { plan: 'BUSINESS' },
        }),
      }),
    );

    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(buffer as any);
    const ws = wb.getWorksheet('Stores');
    expect(ws?.rowCount).toBe(2); // header + 1 data row
    const row = ws?.getRow(2);
    expect(row?.getCell(1).value).toBe('Bozor Plus');
    expect(row?.getCell(3).value).toBe('Фарход');
    expect(row?.getCell(5).value).toBe('BUSINESS');
  });

  it('exportSubscriptions produces an xlsx buffer with one row per subscription, honoring plan/status filters', async () => {
    const buffer = await service.exportSubscriptions({
      plan: 'PREMIUM',
      status: 'TRIAL',
    } as any);

    expect(prisma.subscription.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { plan: 'PREMIUM', status: 'TRIAL' },
      }),
    );

    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(buffer as any);
    const ws = wb.getWorksheet('Subscriptions');
    expect(ws?.rowCount).toBe(2); // header + 1 data row
    const row = ws?.getRow(2);
    expect(row?.getCell(1).value).toBe('Bozor Plus');
    expect(row?.getCell(4).value).toBe('PREMIUM');
    expect(row?.getCell(5).value).toBe('TRIAL');
  });
});
