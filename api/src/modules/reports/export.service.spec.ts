import { Test, TestingModule } from '@nestjs/testing';
import * as ExcelJS from 'exceljs';
import { ExportService } from './export.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrisma() {
  return {
    sale: { findMany: jest.fn() },
    product: { findMany: jest.fn() },
    customer: { findMany: jest.fn() },
  };
}

describe('ExportService', () => {
  let service: ExportService;
  let prisma: ReturnType<typeof makePrisma>;

  beforeEach(async () => {
    prisma = makePrisma();
    const module: TestingModule = await Test.createTestingModule({
      providers: [ExportService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = module.get(ExportService);
  });

  describe('exportSales', () => {
    it('should return a buffer whose worksheet has the correct column headers', async () => {
      prisma.sale.findMany.mockResolvedValue([
        {
          receiptNo: 'R001',
          createdAt: new Date('2026-07-01T10:00:00Z'),
          customer: { name: 'Алишер', phone: '+992123456789' },
          total: 500,
          paidAmount: 500,
          debtAmount: 0,
          paymentType: 'CASH',
          status: 'COMPLETED',
        },
      ]);

      const buf = await service.exportSales('store-1');

      expect(prisma.sale.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { storeId: 'store-1' } }),
      );

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(buf as any);
      const ws = wb.getWorksheet('Sales')!;

      expect(ws.columnCount).toBe(8);
      expect(ws.getRow(1).getCell(1).value).toBe('Receipt');
      expect(ws.getRow(1).getCell(2).value).toBe('Date');
      expect(ws.getRow(2).getCell(1).value).toBe('R001');
      expect(ws.getRow(2).getCell(4).value).toBe(500);
    });
  });

  describe('exportProducts', () => {
    it('should produce one data row per product and include all 8 columns', async () => {
      prisma.product.findMany.mockResolvedValue([
        {
          name: 'Арбуз',
          sku: 'ARB001',
          barcode: '4600001',
          category: { name: 'Фрукты' },
          sellPrice: 15,
          costPrice: 8,
          quantity: 100,
          unit: 'KG',
        },
        {
          name: 'Дыня',
          sku: null,
          barcode: null,
          category: null,
          sellPrice: 12,
          costPrice: 6,
          quantity: 50,
          unit: 'KG',
        },
      ]);

      const buf = await service.exportProducts('store-1');

      expect(prisma.product.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { storeId: 'store-1', isActive: true },
        }),
      );

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(buf as any);
      const ws = wb.getWorksheet('Products')!;

      expect(ws.columnCount).toBe(8);
      expect(ws.rowCount).toBe(3); // 1 header + 2 data rows
    });
  });

  describe('exportCustomers', () => {
    it('should produce one data row per customer with correct row count', async () => {
      const customers = Array.from({ length: 5 }, (_, i) => ({
        name: `Клиент ${i}`,
        phone: `+99290000000${i}`,
        totalSpent: i * 100,
        debt: 0,
        createdAt: new Date(),
      }));
      prisma.customer.findMany.mockResolvedValue(customers);

      const buf = await service.exportCustomers('store-1');

      expect(prisma.customer.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { storeId: 'store-1', isActive: true },
        }),
      );

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(buf as any);
      const ws = wb.getWorksheet('Customers')!;

      expect(ws.getRow(1).getCell(1).value).toBe('Name');
      expect(ws.rowCount).toBe(6); // 1 header + 5 data
    });
  });
});
