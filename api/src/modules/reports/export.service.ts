import { Injectable, BadRequestException } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * D.2 — xlsx export for the PREMIUM `hasExport` tier. Streams an
 * .xlsx file generated from the same data the in-app list shows.
 *
 * Why ExcelJS (not the existing xlsx package): xlsx-js mutates global
 * state when writing styled workbooks; ExcelJS streams cleanly and
 * already drives our import path.
 */
@Injectable()
export class ExportService {
  constructor(private prisma: PrismaService) {}

  async exportSales(storeId: string): Promise<Buffer> {
    const sales = await this.prisma.sale.findMany({
      where: { storeId },
      orderBy: { createdAt: 'desc' },
      include: { customer: { select: { name: true, phone: true } } },
      take: 10000,
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Sales');
    ws.columns = [
      { header: 'Receipt', key: 'receiptNo', width: 14 },
      { header: 'Date', key: 'createdAt', width: 20 },
      { header: 'Customer', key: 'customerName', width: 24 },
      { header: 'Total', key: 'total', width: 12 },
      { header: 'Paid', key: 'paidAmount', width: 12 },
      { header: 'Debt', key: 'debtAmount', width: 12 },
      { header: 'Payment', key: 'paymentType', width: 12 },
      { header: 'Status', key: 'status', width: 14 },
    ];

    for (const s of sales) {
      ws.addRow({
        receiptNo: s.receiptNo,
        createdAt: s.createdAt.toISOString(),
        customerName: s.customer?.name ?? '',
        total: Number(s.total),
        paidAmount: Number(s.paidAmount),
        debtAmount: Number(s.debtAmount),
        paymentType: s.paymentType,
        status: s.status,
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  async exportProducts(storeId: string): Promise<Buffer> {
    const products = await this.prisma.product.findMany({
      where: { storeId, isActive: true },
      orderBy: { name: 'asc' },
      include: { category: { select: { name: true } } },
      take: 10000,
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Products');
    ws.columns = [
      { header: 'Name', key: 'name', width: 30 },
      { header: 'SKU', key: 'sku', width: 16 },
      { header: 'Barcode', key: 'barcode', width: 18 },
      { header: 'Category', key: 'category', width: 20 },
      { header: 'Sell Price', key: 'sellPrice', width: 12 },
      { header: 'Cost Price', key: 'costPrice', width: 12 },
      { header: 'Quantity', key: 'quantity', width: 10 },
      { header: 'Unit', key: 'unit', width: 8 },
    ];

    for (const p of products) {
      ws.addRow({
        name: p.name,
        sku: p.sku ?? '',
        barcode: p.barcode ?? '',
        category: p.category?.name ?? '',
        sellPrice: Number(p.sellPrice),
        costPrice: Number(p.costPrice),
        quantity: Number(p.quantity),
        unit: p.unit,
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  async exportCustomers(storeId: string): Promise<Buffer> {
    const customers = await this.prisma.customer.findMany({
      where: { storeId, isActive: true },
      orderBy: { name: 'asc' },
      take: 10000,
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Customers');
    ws.columns = [
      { header: 'Name', key: 'name', width: 30 },
      { header: 'Phone', key: 'phone', width: 18 },
      { header: 'Total Spent', key: 'totalSpent', width: 14 },
      { header: 'Debt', key: 'debt', width: 12 },
      { header: 'Created', key: 'createdAt', width: 20 },
    ];

    for (const c of customers) {
      ws.addRow({
        name: c.name,
        phone: c.phone ?? '',
        totalSpent: Number(c.totalSpent),
        debt: Number(c.debt),
        createdAt: c.createdAt.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  filenameFor(type: 'sales' | 'products' | 'customers'): string {
    const stamp = new Date().toISOString().slice(0, 10);
    return `dukonpro-${type}-${stamp}.xlsx`;
  }

  validateType(type: string): 'sales' | 'products' | 'customers' {
    if (type !== 'sales' && type !== 'products' && type !== 'customers') {
      throw new BadRequestException(
        'type must be one of: sales, products, customers',
      );
    }
    return type;
  }
}
