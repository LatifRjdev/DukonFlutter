// api/src/common/prisma/query-counter.middleware.ts
//
// Prisma client extension that increments the per-request query
// counter for every query operation. Prisma 6 removed the $use
// middleware API in favor of $extends; this exports a query
// extension that PrismaService applies via this.$extends() in
// onModuleInit.
import { Prisma } from '@prisma/client';
import { incrementCounter } from './query-counter.context';

export const queryCounterExtension = Prisma.defineExtension({
  name: 'queryCounter',
  query: {
    $allModels: {
      async $allOperations({ args, query }) {
        incrementCounter();
        return query(args);
      },
    },
  },
});
