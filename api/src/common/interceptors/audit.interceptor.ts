import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

// Field names redacted from audit_log.details before persisting. Keyed by
// exact property name (not path) — request bodies in this app are shallow
// DTOs, so a top-level check is sufficient today. Extend this set rather
// than adding per-route special-casing if a new sensitive field shows up.
const SENSITIVE_FIELDS = new Set([
  'password',
  'newPassword',
  'currentPassword',
  'oldPassword',
  'token',
  'accessToken',
  'refreshToken',
]);

// Maps the entityType string derived from the route (admin/users/:id ->
// "users") to the Prisma delegate + primary-key field name needed to read
// a before/after snapshot. Only entities admins actually mutate through
// these routes need an entry here — anything else falls back to using the
// response body as "after" with a null "before" (see CREATE-route handling
// below), which is correct behavior, not a gap.
const ENTITY_MODELS: Record<string, { model: string; pkField: string }> = {
  users: { model: 'user', pkField: 'id' },
  stores: { model: 'store', pkField: 'id' },
  subscriptions: { model: 'subscription', pkField: 'id' },
  plans: { model: 'subscriptionPlanConfig', pkField: 'plan' },
};

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const method: string = request.method;

    const isAdminRoute: boolean =
      (request.url as string).includes('/admin/') ||
      (request.url as string).startsWith('/admin');

    const shouldAudit =
      isAdminRoute && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method);

    if (!shouldAudit) {
      return next.handle();
    }

    const routePath: string = request.route?.path ?? request.url ?? '';
    const entityType = this.deriveEntityType(routePath);
    const entityId: string | undefined =
      request.params?.id ?? request.params?.plan ?? undefined;

    const beforeSnapshot = this.captureSnapshot(entityType, entityId);

    return next.handle().pipe(
      tap((response) => {
        const userId: string = request.user?.id ?? 'unknown';
        const action = this.deriveAction(routePath, method);
        const ip: string =
          request.ip ?? request.headers?.['x-forwarded-for'] ?? undefined;

        const afterSnapshot = entityId
          ? this.captureSnapshot(entityType, entityId)
          : Promise.resolve(response ?? request.body);

        // Fire-and-forget — never block the response
        Promise.all([beforeSnapshot, afterSnapshot])
          .then(([before, after]) =>
            this.prisma.auditLog.create({
              data: {
                userId,
                action,
                entityType,
                entityId,
                details: {
                  before: this.redactObject(before),
                  after: this.redactObject(after),
                },
                ip,
              },
            }),
          )
          .catch(() => {
            // silently ignore audit write errors
          });
      }),
    );
  }

  private async captureSnapshot(
    entityType: string,
    entityId?: string,
  ): Promise<Record<string, unknown> | null> {
    const config = ENTITY_MODELS[entityType];
    if (!config || !entityId) return null;
    try {
      const delegate = (this.prisma as any)[config.model];
      return await delegate.findUnique({
        where: { [config.pkField]: entityId },
      });
    } catch {
      return null;
    }
  }

  // Shallow-clones an object and replaces any top-level sensitive field
  // with a fixed marker, so the audit trail records that a value was
  // present without persisting the value itself. Applied independently to
  // both the "before" and "after" snapshots.
  private redactObject(obj: unknown): any {
    if (!obj || typeof obj !== 'object') return obj;
    const clone: Record<string, unknown> = {
      ...(obj as Record<string, unknown>),
    };
    for (const key of Object.keys(clone)) {
      if (SENSITIVE_FIELDS.has(key)) {
        clone[key] = '[REDACTED]';
      }
    }
    return clone;
  }

  private deriveAction(routePath: string, method: string): string {
    const segment = routePath.split('/').filter(Boolean).slice(0, 3).join('/');
    const methodMap: Record<string, string> = {
      POST: 'CREATE',
      PUT: 'UPDATE',
      PATCH: 'UPDATE',
      DELETE: 'DELETE',
    };
    return `${methodMap[method] ?? method}:${segment}`;
  }

  private deriveEntityType(routePath: string): string {
    const parts = routePath.split('/').filter(Boolean);
    // admin/users/:id -> users, admin/stores/:id/suspend -> stores
    return parts[1] ?? parts[0] ?? 'unknown';
  }
}
