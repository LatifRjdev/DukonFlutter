// api/src/common/prisma/query-counter.middleware.ts
//
// Attaches a query-counter to a PrismaClient. Prisma 6 removed
// $use, and $on('query') events do NOT propagate AsyncLocalStorage
// (they're emitted from an internal EventEmitter outside our async
// chain). The only way to preserve the request context across
// queries is $extends with a query callback — it runs inline in the
// call chain so AsyncLocalStorage is visible.
//
// To avoid changing the PrismaClient TS type (which would force
// every consumer to migrate), we apply $extends at runtime and
// copy the extended model proxies back onto the base instance.
// External callers continue to see the standard PrismaClient API.
import { PrismaClient } from '@prisma/client';
import { incrementCounter } from './query-counter.context';

export function attachQueryCounter(prisma: PrismaClient): void {
  const ext = prisma.$extends({
    query: {
      $allOperations({
        args,
        query,
      }: {
        args: unknown;
        query: (a: unknown) => Promise<unknown>;
      }) {
        incrementCounter();
        return query(args);
      },
    },
  });

  // Copy model accessors (prisma.user, prisma.product, etc.) from
  // the extended client back onto the base. Skip dunder / $-prefixed
  // properties (those are PrismaClient internals like $connect,
  // $transaction, $on, etc. which we want to keep on the base).
  for (const key of Object.keys(ext)) {
    if (key.startsWith('$') || key.startsWith('_')) continue;
    const value = (ext as unknown as Record<string, unknown>)[key];
    if (value !== null && typeof value === 'object') {
      (prisma as unknown as Record<string, unknown>)[key] = value;
    }
  }
}
