import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import * as ExcelJS from 'exceljs';
import { AdminExportService } from './admin-export.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    user: {
      findMany: jest.fn(async () => [
        { id: 'u1', name: 'Алишер', phone: '+992900000001', email: null, isAdmin: false, isActive: true, createdAt: new Date('2026-01-01') },
      ]),
    },
    store: {
      findMany: jest.fn(async () => [] as any[]),
    },
  };
}

describe('AdminExportService', () => {
  let service: AdminExportService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [AdminExportService, { provide: PrismaService, useValue: prisma }],
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
});
