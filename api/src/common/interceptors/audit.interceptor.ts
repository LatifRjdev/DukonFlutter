import {
  Injectable,
  Logger,
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
  banners: { model: 'banner', pkField: 'id' },
  // Covers POST /admin/impersonation/:id/end (deriveEntityType resolves
  // "admin/impersonation/:id/end" -> "impersonation"). See deriveEntityType()
  // for the special-cased POST /admin/users/:id/impersonate route, which
  // would otherwise resolve to "users" despite creating an
  // ImpersonationRequest rather than mutating the target User.
  impersonation: { model: 'impersonationRequest', pkField: 'id' },
};

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AuditInterceptor.name);

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

    // POST /admin/users/:id/impersonate is a CREATE — it mints a brand new
    // ImpersonationRequest — but its :id param is the *target user's* id,
    // not the created request's id. Snapshotting ENTITY_MODELS.impersonation
    // by that id would look up a row that doesn't exist (wrong pk), so this
    // route is treated the same as any other bodyless CREATE with no usable
    // entityId: null "before", response body as "after". This is what
    // actually gets the created ImpersonationRequest into the audit trail,
    // rather than a misleading null/null "no changes" diff.
    const isImpersonationCreateRoute =
      method === 'POST' && routePath.endsWith('/impersonate');

    const beforeSnapshot = isImpersonationCreateRoute
      ? Promise.resolve(null)
      : this.captureSnapshot(entityType, entityId);

    return next.handle().pipe(
      tap((response) => {
        const userId: string = request.user?.id ?? 'unknown';
        const action = this.deriveAction(routePath, method);
        const ip: string =
          request.ip ?? request.headers?.['x-forwarded-for'] ?? undefined;
        // NOTE: this interceptor only runs on Admin*Controller routes
        // (@UseInterceptors(AuditInterceptor) is applied per-controller,
        // never globally). An impersonated session's user is always
        // non-admin, so it can never pass AdminGuard and never reaches a
        // route where this tagging applies. It therefore covers only
        // admin-panel-initiated actions (e.g. an admin ending someone
        // else's session), not the ordinary /stores/:storeId/* routes an
        // impersonated session actually hits — those go through the
        // separate AuditLogService, which does not yet know about
        // impersonatedBy/impersonationRequestId. Known gap, tracked
        // separately.
        const viaImpersonation: boolean = !!request.user?.impersonatedBy;

        const afterSnapshot =
          entityId && !isImpersonationCreateRoute
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
                  ...(viaImpersonation && { viaImpersonation: true }),
                },
                ip,
              },
            }),
          )
          .catch((err) => {
            // Non-fatal — never block the response — but log so a broken
            // audit pipeline doesn't fail silently forever.
            this.logger.warn(
              `Failed to write audit log entry for ${action} ${entityType}${entityId ? `/${entityId}` : ''}: ${err}`,
            );
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
    } catch (err) {
      this.logger.warn(
        `Failed to capture audit snapshot for ${entityType}/${entityId}: ${err}`,
      );
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
    // POST /admin/users/:id/impersonate creates an ImpersonationRequest, not
    // a User mutation — but its URL shape places "users" at parts[1], which
    // would otherwise misclassify it. Special-case it ahead of the generic
    // segment-based derivation so both the persisted AuditLog.entityType and
    // the ENTITY_MODELS lookup reflect what's actually being created.
    if (routePath.endsWith('/impersonate')) {
      return 'impersonation';
    }
    const parts = routePath.split('/').filter(Boolean);
    // admin/users/:id -> users, admin/stores/:id/suspend -> stores
    return parts[1] ?? parts[0] ?? 'unknown';
  }
}
