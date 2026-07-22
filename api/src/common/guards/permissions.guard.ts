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

/**
 * Enforces @Permissions(...) on a route. checkStaffPermission() returns a
 * bare boolean, so this guard cannot distinguish "not staff on this store
 * at all" from "staff, but under-permissioned" — both produce the same
 * 403 message below. Today the more specific "you do not have access to
 * this store" message still surfaces in practice because every current
 * route applies StoreAccessGuard before PermissionsGuard, and
 * StoreAccessGuard throws that message first. That ordering is NOT
 * enforced by this guard or by any shared decorator — controllers compose
 * their guard lists independently (see stores.controller.ts) — so don't
 * assume it holds for a new route without checking its guard order.
 */
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
