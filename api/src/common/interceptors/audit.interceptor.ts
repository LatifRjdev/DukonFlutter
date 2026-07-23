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

    return next.handle().pipe(
      tap(() => {
        const userId: string = request.user?.id ?? 'unknown';
        const routePath: string = request.route?.path ?? request.url ?? '';
        const action = this.deriveAction(routePath, method);
        const entityType = this.deriveEntityType(routePath);
        const entityId: string | undefined =
          request.params?.id ?? request.params?.plan ?? undefined;
        const ip: string =
          request.ip ?? request.headers?.['x-forwarded-for'] ?? undefined;

        // Fire-and-forget — never block the response
        this.prisma.auditLog
          .create({
            data: {
              userId,
              action,
              entityType,
              entityId,
              details: this.redact(request.body) ?? null,
              ip,
            },
          })
          .catch(() => {
            // silently ignore audit write errors
          });
      }),
    );
  }

  // Shallow-clones the request body and replaces any top-level sensitive
  // field with a fixed marker, so the audit trail records that a value
  // was present without persisting the value itself.
  private redact(body: unknown): any {
    if (!body || typeof body !== 'object') return body;
    const clone: Record<string, unknown> = {
      ...(body as Record<string, unknown>),
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
