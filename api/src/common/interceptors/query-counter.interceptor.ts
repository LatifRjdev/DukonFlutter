// api/src/common/interceptors/query-counter.interceptor.ts
//
// Wraps every HTTP request in the query-counter AsyncLocalStorage
// context. Logs a warning at end-of-request if count > 10, error
// if count > 25.
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, from, switchMap, tap } from 'rxjs';
import {
  readCounter,
  runWithCounter,
} from '../prisma/query-counter.context';

const WARN_THRESHOLD = 10;
const ERROR_THRESHOLD = 25;

@Injectable()
export class QueryCounterInterceptor implements NestInterceptor {
  private readonly logger = new Logger('QueryCounter');

  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const req = context.switchToHttp().getRequest<{
      method: string;
      url: string;
    }>();
    const endpoint = `${req.method} ${req.url}`;
    return from(
      runWithCounter(endpoint, () =>
        next.handle().toPromise() as Promise<unknown>,
      ),
    ).pipe(
      tap(() => {
        const store = readCounter();
        if (!store) return;
        if (store.count > ERROR_THRESHOLD) {
          this.logger.error(
            `${endpoint} fired ${store.count} queries (> ${ERROR_THRESHOLD})`,
          );
        } else if (store.count > WARN_THRESHOLD) {
          this.logger.warn(
            `${endpoint} fired ${store.count} queries (> ${WARN_THRESHOLD})`,
          );
        }
      }),
      switchMap((v) => from(Promise.resolve(v))),
    );
  }
}
