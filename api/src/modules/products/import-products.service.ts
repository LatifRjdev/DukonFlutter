import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import * as ExcelJS from 'exceljs';

interface ParsedRow {
  row: number;
  name: string;
  barcode?: string;
  category?: string;
  purchasePrice?: number;
  salePrice: number;
  quantity: number;
  unit: string;
  description?: string;
}

export interface RowError {
  row: number;
  field: string;
  message: string;
}

const UNIT_MAP: Record<string, string> = {
  'шт': 'PCS',
  'штук': 'PCS',
  'штука': 'PCS',
  'pcs': 'PCS',
  'кг': 'KG',
  'kg': 'KG',
  'л': 'L',
  'литр': 'L',
  'l': 'L',
  'м': 'M',
  'метр': 'M',
  'm': 'M',
  'уп': 'PACK',
  'упаковка': 'PACK',
  'pack': 'PACK',
};

@Injectable()
export class ImportProductsService {
  constructor(private prisma: PrismaService) {}

  async parseFile(buffer: Buffer): Promise<{ rows: ParsedRow[]; errors: RowError[] }> {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer as any);

    const sheet = workbook.worksheets[0];
    if (!sheet) {
      throw new BadRequestException('Файл не содержит листов');
    }

    const rows: ParsedRow[] = [];
    const errors: RowError[] = [];

    sheet.eachRow((row, rowNumber) => {
      if (rowNumber === 1) return; // skip header

      const name = row.getCell(1).text?.trim();
      const barcode = row.getCell(2).text?.trim() || undefined;
      const category = row.getCell(3).text?.trim() || undefined;
      const purchasePriceRaw = row.getCell(4).value;
      const salePriceRaw = row.getCell(5).value;
      const quantityRaw = row.getCell(6).value;
      const unitRaw = row.getCell(7).text?.trim()?.toLowerCase() || 'шт';
      const description = row.getCell(8).text?.trim() || undefined;

      // Skip completely empty rows
      if (!name && !barcode && !salePriceRaw) return;

      // Validate name
      if (!name) {
        errors.push({ row: rowNumber, field: 'name', message: 'Название обязательно' });
        return;
      }

      // Validate sale price
      const salePrice = typeof salePriceRaw === 'number'
        ? salePriceRaw
        : parseFloat(String(salePriceRaw));
      if (!salePrice || isNaN(salePrice) || salePrice <= 0) {
        errors.push({ row: rowNumber, field: 'salePrice', message: 'Цена продажи обязательна и должна быть > 0' });
        return;
      }

      const purchasePrice = purchasePriceRaw
        ? (typeof purchasePriceRaw === 'number' ? purchasePriceRaw : parseFloat(String(purchasePriceRaw)))
        : undefined;
      if (purchasePrice !== undefined && (isNaN(purchasePrice) || purchasePrice < 0)) {
        errors.push({ row: rowNumber, field: 'purchasePrice', message: 'Некорректная цена закупки' });
        return;
      }

      const quantity = quantityRaw
        ? (typeof quantityRaw === 'number' ? Math.floor(quantityRaw) : parseInt(String(quantityRaw), 10))
        : 0;
      if (isNaN(quantity) || quantity < 0) {
        errors.push({ row: rowNumber, field: 'quantity', message: 'Некорректное количество' });
        return;
      }

      const unit = UNIT_MAP[unitRaw] || 'PCS';

      rows.push({
        row: rowNumber,
        name,
        barcode,
        category,
        purchasePrice,
        salePrice,
        quantity,
        unit,
        description,
      });
    });

    return { rows, errors };
  }

  async preview(buffer: Buffer) {
    const { rows, errors } = await this.parseFile(buffer);
    return {
      totalRows: rows.length,
      previewRows: rows.slice(0, 20).map((r) => ({
        name: r.name,
        barcode: r.barcode,
        category: r.category,
        salePrice: r.salePrice,
        quantity: r.quantity,
        unit: r.unit,
      })),
      errors,
    };
  }

  async importProducts(storeId: string, buffer: Buffer) {
    const { rows, errors } = await this.parseFile(buffer);

    if (rows.length === 0) {
      throw new BadRequestException('Файл не содержит данных для импорта');
    }

    if (rows.length > 1000) {
      throw new BadRequestException('Максимум 1000 товаров за один импорт');
    }

    let created = 0;
    let skipped = 0;
    const importErrors: RowError[] = [...errors];

    // Collect unique category names
    const categoryNames = [...new Set(rows.map((r) => r.category).filter(Boolean))] as string[];

    // Auto-create or find categories
    const categoryMap = new Map<string, string>();
    for (const catName of categoryNames) {
      const existing = await this.prisma.category.findUnique({
        where: { storeId_name: { storeId, name: catName } },
      });
      if (existing) {
        categoryMap.set(catName, existing.id);
      } else {
        const created = await this.prisma.category.create({
          data: { storeId, name: catName },
        });
        categoryMap.set(catName, created.id);
      }
    }

    // Fetch existing barcodes for this store
    const existingBarcodes = new Set(
      (
        await this.prisma.product.findMany({
          where: { storeId, barcode: { not: null } },
          select: { barcode: true },
        })
      ).map((p) => p.barcode),
    );

    // Import in transaction
    await this.prisma.$transaction(async (tx) => {
      for (const row of rows) {
        // Check barcode uniqueness
        if (row.barcode && existingBarcodes.has(row.barcode)) {
          importErrors.push({
            row: row.row,
            field: 'barcode',
            message: `Штрихкод ${row.barcode} уже существует`,
          });
          skipped++;
          continue;
        }

        try {
          await tx.product.create({
            data: {
              storeId,
              name: row.name,
              barcode: row.barcode || null,
              categoryId: row.category ? (categoryMap.get(row.category) ?? null) : null,
              costPrice: row.purchasePrice ?? null,
              sellPrice: row.salePrice,
              quantity: row.quantity,
              unit: row.unit as any,
              description: row.description || null,
            },
          });
          created++;

          // Track barcode to prevent duplicates within import
          if (row.barcode) {
            existingBarcodes.add(row.barcode);
          }
        } catch (e: any) {
          importErrors.push({
            row: row.row,
            field: 'general',
            message: e.message || 'Ошибка создания товара',
          });
          skipped++;
        }
      }
    });

    return { created, skipped, errors: importErrors };
  }
}
