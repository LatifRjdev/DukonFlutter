// api/src/common/interceptors/query-counter.interceptor.ts
//
// Wraps every HTTP request in the query-counter AsyncLocalStorage
// context. Logs a warning at end-of-request if count > 10, error
// if count > 25.
//
// Implementation note: we pass a per-request `store` object into
// runWithCounter(). The Prisma $extends query callback (set up in
// attachQueryCounter) increments store.count inside the
// AsyncLocalStorage scope. After the controller handler resolves,
// we read store.count directly — no need to re-enter the storage
// context (we already hold the ref).
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, from, firstValueFrom } from 'rxjs';
import {
  QueryCounterStore,
  runWithCounter,
} from '../prisma/query-counter.context';

const WARN_THRESHOLD = 10;
const ERROR_THRESHOLD = 25;

@Injectable()
export class QueryCounterInterceptor implements NestInterceptor {
  private readonly logger = new Logger('QueryCounter');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<{
      method: string;
      url: string;
    }>();
    const endpoint = `${req.method} ${req.url}`;
    const store: QueryCounterStore = { count: 0, endpoint };

    const promise = runWithCounter(store, async () => {
      const value = await firstValueFrom(next.handle());
      return value;
    }).then((value) => {
      if (store.count > ERROR_THRESHOLD) {
        this.logger.error(
          `${endpoint} fired ${store.count} queries (> ${ERROR_THRESHOLD})`,
        );
      } else if (store.count > WARN_THRESHOLD) {
        this.logger.warn(
          `${endpoint} fired ${store.count} queries (> ${WARN_THRESHOLD})`,
        );
      }
      return value;
    });

    return from(promise);
  }
}
