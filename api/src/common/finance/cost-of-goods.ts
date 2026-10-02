import { PrismaService } from '../../prisma/prisma.service';

/**
 * Cost of goods sold for one store over a period.
 *
 * Reads SaleItem.costPrice — the cost SNAPSHOT taken when the sale was made —
 * not the product's current costPrice. Re-pricing a product must not rewrite
 * the margin on sales that already happened.
 *
 * Refunds do NOT reach the subtraction today: SalesService.refund moves the
 * sale to RETURNED or PARTIALLY_RETURNED in the same transaction that
 * increments refundedQuantity, so the COMPLETED filter already excludes such a
 * sale in its entirety. That matches how revenue treats it — the revenue
 * aggregates use the identical filter — so margins stay consistent. The
 * `- refundedQuantity` term is kept so this aggregate stays correct if that
 * filter is ever widened; widening it here alone would understate margin.
 *
 * A NULL costPrice contributes 0. None exist today (verified across every
 * store), but an import path that skipped the snapshot would silently
 * understate the result — and 0 is the only honest default, since the
 * historical cost cannot be reconstructed.
 *
 * Lives here rather than in either service because the finance dashboard and
 * the profit report both show this number, one tap apart. They each had their
 * own copy of the aggregate and the copies had already drifted: the reports
 * one omitted the refund term while its comment claimed parity. One
 * definition is what keeps the two screens agreeing.
 *
 * Known inconsistency, deliberately left alone: getDashboard's topProducts
 * does include PARTIALLY_RETURNED, so it disagrees with revenue and cost about
 * partially refunded sales.
 */
export async function computeCostOfGoods(
  prisma: PrismaService,
  storeId: string,
  startDate: Date,
  endDate: Date,
): Promise<number> {
  const rows = await prisma.$queryRaw<{ cogs: string | null }[]>`
    SELECT COALESCE(
      SUM((si."quantity" - si."refundedQuantity") * si."costPrice"), 0
    )::text AS cogs
    FROM sale_items si
    JOIN sales s ON s.id = si."saleId"
    WHERE s."storeId" = ${storeId}
      AND s."status" = 'COMPLETED'
      AND s."createdAt" >= ${startDate}
      AND s."createdAt" <= ${endDate}
  `;
  // ::text rather than ::float: a numeric(12,2) sum is exact in Postgres, and
  // routing it through text keeps it exact until Number() instead of through
  // float8.
  return Number(rows[0]?.cogs ?? 0);
}
