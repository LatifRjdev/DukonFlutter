// api/src/common/prisma/query-counter.middleware.ts
//
// Attaches a query-counter listener to a PrismaClient. Prisma 6
// removed the $use middleware API; using $extends would change
// the client's TS type and force every consumer to migrate. The
// simpler path is Prisma's $on('query') event listener, which
// works as long as the client is constructed with the matching
// log config (see PrismaService).
import { PrismaClient } from '@prisma/client';
import { incrementCounter } from './query-counter.context';

export function attachQueryCounter(prisma: PrismaClient): void {
  // $on('query', ...) is only typed when the client is built with
  // log: [{ emit: 'event', level: 'query' }]. Cast to bypass the
  // narrowing — PrismaService guarantees the right config.
  (prisma as unknown as {
    $on(event: 'query', listener: () => void): void;
  }).$on('query', () => incrementCounter());
}
