import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class BannersService {
  constructor(private prisma: PrismaService) {}

  async getActiveBanner(storeId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { subscription: { select: { plan: true, status: true } } },
    });
    if (!store) return null;

    const now = new Date();
    // A store without a subscription row only matches wildcard (no
    // targetPlan) banners — it must NOT fall through to "no plan
    // filter applied", which would incorrectly show plan-targeted
    // banners to every unsubscribed store.
    const candidates = await this.prisma.banner.findMany({
      where: {
        active: true,
        startDate: { lte: now },
        endDate: { gte: now },
        OR: store.subscription?.plan
          ? [{ targetPlan: null }, { targetPlan: store.subscription.plan }]
          : [{ targetPlan: null }],
      },
      orderBy: { createdAt: 'desc' },
    });

    const matching = candidates.filter(
      (b) => !b.targetStatus || b.targetStatus === store.subscription?.status,
    );

    return matching[0] ?? null;
  }
}
