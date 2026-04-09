import { Injectable, CanActivate, ExecutionContext, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class StoreAccessGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    const storeId = request.params.storeId;

    if (!storeId || !userId) {
      throw new ForbiddenException('Access denied');
    }

    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { ownerId: true },
    });

    if (!store) {
      throw new NotFoundException('Store not found');
    }

    if (store.ownerId === userId) {
      return true;
    }

    const staffRecord = await this.prisma.staff.findUnique({
      where: { storeId_userId: { storeId, userId } },
      select: { isActive: true },
    });

    if (staffRecord?.isActive) {
      return true;
    }

    throw new ForbiddenException('You do not have access to this store');
  }
}
