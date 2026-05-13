// api/src/common/prisma/query-counter.context.ts
//
// AsyncLocalStorage-backed per-request query counter for Prisma.
// The interceptor calls runWithCounter() at the top of each HTTP
// request; the Prisma middleware calls incrementCounter() on each
// query; the interceptor reads the final count at end-of-request.
import { AsyncLocalStorage } from 'node:async_hooks';

export interface QueryCounterStore {
  count: number;
  endpoint: string;
}

const storage = new AsyncLocalStorage<QueryCounterStore>();

export function runWithCounter<T>(
  endpoint: string,
  fn: () => Promise<T>,
): Promise<T> {
  return storage.run({ count: 0, endpoint }, fn);
}

export function incrementCounter(): void {
  const store = storage.getStore();
  if (store) store.count += 1;
}

export function readCounter(): QueryCounterStore | undefined {
  return storage.getStore();
}
