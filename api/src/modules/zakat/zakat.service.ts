import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpsertZakatSettingsDto } from './dto/upsert-zakat-settings.dto';
import { CreateZakatPaymentDto } from './dto/create-zakat-payment.dto';

@Injectable()
export class ZakatService {
  constructor(private prisma: PrismaService) {}

  async calculate(storeId: string) {
    const settings = await this.getSettings(storeId);
    const zakatRate = settings ? Number(settings.zakatRate) : 2.5;

    // Calculate stock value (sum of all active products: quantity * costPrice or sellPrice)
    const stockValue = await this.prisma.product.aggregate({
      where: { storeId, isActive: true, quantity: { gt: 0 } },
      _sum: { costPrice: true, sellPrice: true },
    });

    // More accurate: sum(quantity * costPrice) using raw query
    const stockResult = await this.prisma.$queryRaw<[{ total: number }]>`
      SELECT COALESCE(SUM(quantity * COALESCE("costPrice", "sellPrice")), 0)::float as total
      FROM products
      WHERE "storeId" = ${storeId} AND "isActive" = true AND quantity > 0
    `;
    const inventoryValue = stockResult[0]?.total || 0;

    // Customer debts (receivables - money owed TO us)
    const receivables = await this.prisma.customer.aggregate({
      where: { storeId, debt: { gt: 0 } },
      _sum: { debt: true },
    });
    const totalReceivables = Number(receivables._sum.debt || 0);

    // Supplier debts (payables - money WE owe)
    const payables = await this.prisma.supplier.aggregate({
      where: { storeId, debt: { gt: 0 } },
      _sum: { debt: true },
    });
    const totalPayables = Number(payables._sum.debt || 0);

    // Calculate zakateable assets
    const breakdown = {
      inventoryValue: settings?.includeStock !== false ? inventoryValue : 0,
      cashOnHand: 0, // User needs to input this manually in frontend
      receivables: settings?.includeDebts !== false ? totalReceivables : 0,
      payables: totalPayables,
    };

    const totalAssets = breakdown.inventoryValue + breakdown.cashOnHand + breakdown.receivables;
    const netAssets = totalAssets - breakdown.payables;
    const nisabAmount = settings ? Number(settings.nisabAmount) : 0;
    // G.2: previous default when nisabAmount is unset was
    // `isAboveNisab=true` — that ALWAYS triggered zakat on any
    // positive netAssets, including amounts well below the
    // religiously-required threshold. The conservative default for
    // users who haven't set their nisab is "no zakat due"; they
    // need to opt in explicitly via Zakat settings. Net-negative
    // also short-circuits to zero (was previously missing).
    const isAboveNisab =
      nisabAmount > 0 ? netAssets >= nisabAmount : false;
    const zakatDue =
      isAboveNisab && netAssets > 0 ? (netAssets * zakatRate) / 100 : 0;

    return {
      breakdown,
      totalAssets,
      netAssets,
      nisabAmount,
      isAboveNisab,
      zakatRate,
      zakatDue,
      haulStartDate: settings?.haulStartDate,
    };
  }

  async getSettings(storeId: string) {
    const settings = await this.prisma.zakatSettings.findUnique({
      where: { storeId },
    });
    if (settings) return settings;
    // No row yet — return schema defaults so clients always get a stable JSON
    // body. Previously null from Prisma serialized to an empty response body,
    // which crashed the Flutter DTO parser (FD-P0-001).
    return {
      id: '',
      storeId,
      nisabGold: 85,
      nisabSilver: 595,
      nisabCurrency: 'TJS',
      nisabAmount: 0,
      haulStartDate: null as Date | null,
      zakatRate: 2.5,
      includeStock: true,
      includeCash: true,
      includeDebts: true,
    };
  }

  async upsertSettings(storeId: string, dto: UpsertZakatSettingsDto) {
    return this.prisma.zakatSettings.upsert({
      where: { storeId },
      create: {
        storeId,
        ...dto,
        haulStartDate: dto.haulStartDate ? new Date(dto.haulStartDate) : undefined,
      },
      update: {
        ...dto,
        haulStartDate: dto.haulStartDate ? new Date(dto.haulStartDate) : undefined,
      },
    });
  }

  async getPayments(storeId: string) {
    return this.prisma.zakatPayment.findMany({
      where: { storeId },
      orderBy: { paidAt: 'desc' },
    });
  }

  async createPayment(storeId: string, dto: CreateZakatPaymentDto) {
    return this.prisma.zakatPayment.create({
      data: {
        storeId,
        amount: dto.amount,
        totalAssets: dto.totalAssets || 0,
        zakatDue: dto.zakatDue || dto.amount,
        breakdown: dto.breakdown || {},
        notes: dto.notes,
      },
    });
  }
}
