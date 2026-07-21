import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import {
  hasDefaultPermission,
  legacyPermissionKeyFor,
} from './permissions-matrix';

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
    //
    // BE-P1-011: RolePermission rows are written by RolesService using a
    // legacy snake_case vocabulary (`manage_products`, ...), not the
    // dotted `resource.action` strings required permissions use. Translate
    // each required permission to its legacy key (where one exists) before
    // querying, otherwise the DB lookup below always misses and every
    // override silently no-ops. See permissions-matrix.ts for the alias
    // table and why some permissions are intentionally left unmapped.
    const legacyKeyByPermission = new Map<string, string>();
    for (const perm of requiredPermissions) {
      const legacyKey = legacyPermissionKeyFor(perm);
      if (legacyKey) {
        legacyKeyByPermission.set(perm, legacyKey);
      }
    }
    const dbPermissionKeys = [...new Set(legacyKeyByPermission.values())];

    const rolePermissions = dbPermissionKeys.length
      ? await this.prisma.rolePermission.findMany({
          where: {
            storeId,
            role: staffRecord.role,
            permission: { in: dbPermissionKeys },
          },
          select: { permission: true, isGranted: true },
        })
      : [];

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
      const legacyKey = legacyKeyByPermission.get(perm);
      if (legacyKey) {
        if (dbDeny.has(legacyKey)) return false;
        if (dbAllow.has(legacyKey)) return true;
      }
      // Not mentioned in DB (or not bridged to a legacy key) → consult
      // the hardcoded default matrix.
      return hasDefaultPermission(staffRecord.role, perm);
    });

    if (!hasAll) {
      throw new ForbiddenException('You do not have the required permissions');
    }

    return true;
  }
}
