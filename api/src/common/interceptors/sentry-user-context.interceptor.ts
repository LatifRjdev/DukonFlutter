import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import * as Sentry from '@sentry/nestjs';

/**
 * Spec G A.2: binds the authenticated user (and storeId tag if
 * present in route params) to Sentry scope so any error captured
 * during this request is tagged with the merchant context.
 *
 * userId is our own UUID (not PII like phone) — safe to set even
 * with sendDefaultPii=false.
 */
@Injectable()
export class SentryUserContextInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest();
    const user = req.user as { id?: string } | undefined;
    if (user?.id) {
      Sentry.getCurrentScope().setUser({ id: user.id });
    }
    const storeId = req.params?.storeId as string | undefined;
    if (storeId) {
      Sentry.getCurrentScope().setTag('storeId', storeId);
    }
    return next.handle();
  }
}
