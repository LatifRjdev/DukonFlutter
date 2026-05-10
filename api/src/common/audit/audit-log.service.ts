import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * D.3 — App-wide audit logger. Previously only the admin module
 * recorded sensitive writes. Wire this from any service that mutates
 * money, role, or store-config state and want it traceable.
 *
 * Failure mode: logging is best-effort. We never want a failed audit
 * write to roll back the actual operation, so callers don't await
 * inside transactions and we swallow + log here.
 */
@Injectable()
export class AuditLogService {
  private readonly logger = new Logger(AuditLogService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Record one audit entry. Fire-and-forget — does not throw.
   *
   * @param userId  acting user id (or 'system' for background jobs)
   * @param action  dotted name like 'sale.refund', 'subscription.approve'
   * @param entityType  'sale' | 'subscription' | 'inventory_count' | 'store' | 'staff' | 'debt_payment'
   * @param entityId    id of the row touched
   * @param details     freeform JSON — usually a {before, after, reason} bag
   */
  async record(
    userId: string,
    action: string,
    entityType: string,
    entityId: string | null,
    details?: Record<string, unknown>,
    ip?: string,
  ): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action,
          entityType,
          entityId: entityId ?? undefined,
          details: details as any,
          ip,
        },
      });
    } catch (err) {
      this.logger.error(
        `audit log write failed for ${action}/${entityType}/${entityId}: ${(err as Error).message}`,
      );
    }
  }
}
