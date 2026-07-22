import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { UpsertZakatSettingsDto } from './dto/upsert-zakat-settings.dto';
import { CreateZakatPaymentDto } from './dto/create-zakat-payment.dto';
import * as Sentry from '@sentry/nestjs';

// ZC-P1-1: Hijri lunar year — 354 days. Zakat is only due on
// wealth that has been held above the nisab threshold for one
// full lunar year ("haul"). Captured server-side so the Flutter
// client cannot bypass.
const HAUL_DAYS = 354;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

@Injectable()
export class ZakatService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditLogService,
  ) {}

  /**
   * Z-P1-6: snapshot-isolated, Decimal-safe zakat calculation.
   *
   * - Wraps the 4 read paths (settings + product aggregate + customer
   *   aggregate + supplier aggregate) in `$transaction` so they share a
   *   read snapshot and can't drift from each other under load.
   * - All arithmetic is `Prisma.Decimal` end-to-end. JS `Number` would
   *   lose precision past ~15 significant digits, which is reachable
   *   for stores with >9 figure inventory.
   * - ZC-P1-1: gates `zakatDue = 0` until `now - haulStartDate >= 354
   *   days`. `now` is injectable so tests can freeze time.
   *
   * Response uses `Decimal` instances; the global TransformInterceptor
   * serializes them to JS numbers in the HTTP response so the Flutter
   * `_mapCalculation` num→double path keeps working.
   */
  async calculate(storeId: string, now: Date = new Date()) {
    const [settings, customers, suppliers, stockResult] =
      await this.prisma.$transaction([
        this.prisma.zakatSettings.findUnique({ where: { storeId } }),
        this.prisma.customer.aggregate({
          where: { storeId, debt: { gt: 0 } },
          _sum: { debt: true },
        }),
        this.prisma.supplier.aggregate({
          where: { storeId, debt: { gt: 0 } },
          _sum: { debt: true },
        }),
        this.prisma.$queryRaw<[{ total: string }]>`
          SELECT COALESCE(SUM(quantity * COALESCE("costPrice", "sellPrice")), 0)::text as total
          FROM products
          WHERE "storeId" = ${storeId} AND "isActive" = true AND quantity > 0
        `,
      ]);

    const inventoryRaw = new Decimal(stockResult[0]?.total ?? '0');
    const receivablesRaw = new Decimal(customers._sum.debt ?? 0);
    const payablesRaw = new Decimal(suppliers._sum.debt ?? 0);
    const cashOnHand =
      settings?.includeCash === false
        ? new Decimal(0)
        : new Decimal(settings?.cashOnHand ?? 0);

    const includeStock = settings?.includeStock !== false;
    const includeDebts = settings?.includeDebts !== false;

    const inventoryValue = includeStock ? inventoryRaw : new Decimal(0);
    const receivables = includeDebts ? receivablesRaw : new Decimal(0);
    const payables = payablesRaw;

    const totalAssets = inventoryValue.add(cashOnHand).add(receivables);
    const netAssets = totalAssets.sub(payables);

    const zakatRate = settings
      ? new Decimal(settings.zakatRate)
      : new Decimal('2.5');
    const nisabAmount = settings
      ? new Decimal(settings.nisabAmount)
      : new Decimal(0);
    // G.2: same conservative default — no zakat unless nisabAmount
    // is explicitly configured > 0.
    const isAboveNisab = nisabAmount.gt(0) && netAssets.gte(nisabAmount);

    // ZC-P1-1: haul (354-day holding period) gate.
    const haulStartDate = settings?.haulStartDate ?? null;
    let isHaulComplete = true; // default true if haul date never set (backwards compat)
    let haulCompletesOn: Date | null = null;
    if (haulStartDate) {
      const elapsedDays =
        (now.getTime() - haulStartDate.getTime()) / MS_PER_DAY;
      isHaulComplete = elapsedDays >= HAUL_DAYS;
      if (!isHaulComplete) {
        haulCompletesOn = new Date(
          haulStartDate.getTime() + HAUL_DAYS * MS_PER_DAY,
        );
      }
    }

    const zakatDue =
      isAboveNisab && netAssets.gt(0) && isHaulComplete
        ? netAssets.mul(zakatRate).div(100)
        : new Decimal(0);

    return {
      breakdown: {
        inventoryValue,
        cashOnHand,
        receivables,
        payables,
      },
      totalAssets,
      netAssets,
      nisabAmount,
      isAboveNisab,
      zakatRate,
      zakatDue,
      // ZC-P1-1: surface haul status so Flutter can render
      // "haul completes on YYYY-MM-DD" hint and disable the
      // "mark as paid" CTA when isHaulComplete=false.
      isHaulComplete,
      haulCompletesOn,
      haulStartDate,
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

  async upsertSettings(
    storeId: string,
    dto: UpsertZakatSettingsDto,
    userId: string,
  ) {
    const before = await this.prisma.zakatSettings.findUnique({
      where: { storeId },
    });

    const settings = await this.prisma.zakatSettings.upsert({
      where: { storeId },
      create: {
        storeId,
        ...dto,
        haulStartDate: dto.haulStartDate
          ? new Date(dto.haulStartDate)
          : undefined,
      },
      update: {
        ...dto,
        haulStartDate: dto.haulStartDate
          ? new Date(dto.haulStartDate)
          : undefined,
      },
    });

    // Z-P1-2: audit settings mutation. Fire-and-forget — the
    // AuditLogService swallows its own errors so a logging failure
    // doesn't roll back the upsert.
    await this.audit.record(
      userId,
      'zakat.settings.upsert',
      'zakat_settings',
      settings.id,
      {
        storeId,
        before: before ?? null,
        after: settings,
      },
    );

    return settings;
  }

  // Spec E B.1: pagination. Returns rows + total count + page meta
  // in a single $transaction so the count is consistent with the page.
  // `orderBy: { paidAt: 'desc' }` is asserted in zakat.service.spec.ts
  // (Spec E B.3) so a future refactor can't silently change ordering.
  async getPayments(storeId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total] = await this.prisma.$transaction([
      this.prisma.zakatPayment.findMany({
        where: { storeId },
        orderBy: { paidAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.zakatPayment.count({ where: { storeId } }),
    ]);
    return {
      data,
      total,
      totalPages: total === 0 ? 0 : Math.ceil(total / limit),
      currentPage: page,
    };
  }

  async createPayment(
    storeId: string,
    dto: CreateZakatPaymentDto,
    userId: string,
  ) {
    const calc = await this.calculate(storeId);
    const serverZakatDue = calc.zakatDue;
    const serverTotalAssets = calc.totalAssets;

    const data: Prisma.ZakatPaymentUncheckedCreateInput = {
      storeId,
      amount: new Prisma.Decimal(dto.amount),
      // Z-P1-1: use server-trusted values, NOT the client claim.
      totalAssets: serverTotalAssets,
      zakatDue: serverZakatDue,
      breakdown: (dto.breakdown ?? {}) as Prisma.InputJsonValue,
      notes: dto.notes,
      localId: dto.localId ?? null,
    };

    // Z-P1-1: idempotency — a retried POST with the same localId
    // returns the existing row instead of creating a duplicate.
    // We use `update: {}` so retries are pure no-ops; mutation on
    // retry would defeat the point.
    const payment = dto.localId
      ? await this.prisma.zakatPayment.upsert({
          where: { storeId_localId: { storeId, localId: dto.localId } },
          create: data,
          update: {},
        })
      : await this.prisma.zakatPayment.create({ data });

    Sentry.addBreadcrumb({
      category: 'zakat',
      message: 'zakat.payment.create',
      data: { paymentId: payment.id, amount: payment.amount.toString() },
    });

    // Z-P1-2: audit mutation with the actor's userId.
    await this.audit.record(
      userId,
      'zakat.payment.create',
      'zakat_payment',
      payment.id,
      {
        storeId,
        amount: payment.amount.toString(),
        zakatDue: payment.zakatDue.toString(),
        totalAssets: payment.totalAssets.toString(),
        localId: payment.localId,
      },
    );

    return payment;
  }
}
