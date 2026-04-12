import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

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
              details: request.body ?? null,
              ip,
            },
          })
          .catch(() => {
            // silently ignore audit write errors
          });
      }),
    );
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
