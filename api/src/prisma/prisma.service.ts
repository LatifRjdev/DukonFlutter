import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { attachQueryCounter } from '../common/prisma/query-counter.middleware';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    super({
      log: [{ emit: 'event', level: 'query' }],
    });
  }

  async onModuleInit() {
    attachQueryCounter(this);
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
