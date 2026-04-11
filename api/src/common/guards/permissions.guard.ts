import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { hasDefaultPermission } from './permissions-matrix';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    const storeId = request.params.storeId;

    if (!userId || !storeId) {
      throw new ForbiddenException('Access denied');
    }

    // Check if user is the store owner — always allowed
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { ownerId: true },
    });

    if (store?.ownerId === userId) {
      return true;
    }

    // Get the user's staff role for this store
    const staffRecord = await this.prisma.staff.findUnique({
      where: { storeId_userId: { storeId, userId } },
      select: { role: true, isActive: true },
    });

    if (!staffRecord || !staffRecord.isActive) {
      throw new ForbiddenException('You do not have access to this store');
    }

    // OWNER role always passes
    if (staffRecord.role === 'OWNER') {
      return true;
    }

    // Check role permissions in the database — DB overrides the default
    // matrix, so a store owner can grant or revoke specific actions per
    // role without touching source.
    const rolePermissions = await this.prisma.rolePermission.findMany({
      where: {
        storeId,
        role: staffRecord.role,
        permission: { in: requiredPermissions },
      },
      select: { permission: true, isGranted: true },
    });

    // Build an allow/deny set from DB rows, then fall back to the default
    // matrix for any permission the DB did not mention. Previously this
    // path returned `true` when the DB was empty — that was "default open"
    // and let any non-owner staff hit every decorated endpoint
    // (BE-P1-004).
    const dbAllow = new Set(
      rolePermissions.filter((rp) => rp.isGranted).map((rp) => rp.permission),
    );
    const dbDeny = new Set(
      rolePermissions.filter((rp) => !rp.isGranted).map((rp) => rp.permission),
    );

    const hasAll = requiredPermissions.every((perm) => {
      if (dbDeny.has(perm)) return false;
      if (dbAllow.has(perm)) return true;
      // Not mentioned in DB → consult the hardcoded default matrix.
      return hasDefaultPermission(staffRecord.role, perm);
    });

    if (!hasAll) {
      throw new ForbiddenException('You do not have the required permissions');
    }

    return true;
  }
}
