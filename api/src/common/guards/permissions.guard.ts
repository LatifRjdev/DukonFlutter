import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { checkStaffPermission } from './permission-check.helper';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    const storeId = request.params.storeId;

    if (!userId || !storeId) {
      throw new ForbiddenException('Access denied');
    }

    const allowed = await checkStaffPermission(
      this.prisma,
      storeId,
      userId,
      requiredPermissions,
    );

    if (!allowed) {
      throw new ForbiddenException('You do not have the required permissions');
    }

    return true;
  }
}
