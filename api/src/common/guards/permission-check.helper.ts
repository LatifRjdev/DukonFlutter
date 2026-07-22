import { PrismaService } from '../../prisma/prisma.service';
import { hasDefaultPermission, legacyPermissionKeyFor } from './permissions-matrix';

/**
 * Returns true if `userId` (as staff of `storeId`, or as the store owner)
 * has all of `requiredPermissions`. Never throws — callers that need a
 * hard block (route guards) should throw ForbiddenException themselves
 * based on the boolean result; callers that just want to conditionally
 * shape a response (e.g. include/omit a field) can use the boolean
 * directly.
 *
 * Extracted from PermissionsGuard.canActivate so both the route-level
 * guard and any in-service field-visibility check share one
 * implementation — see permissions.guard.ts for why the DB-override
 * translation (legacyPermissionKeyFor) exists.
 */
export async function checkStaffPermission(
  prisma: PrismaService,
  storeId: string,
  userId: string,
  requiredPermissions: string[],
): Promise<boolean> {
  if (requiredPermissions.length === 0) return true;

  const store = await prisma.store.findUnique({
    where: { id: storeId },
    select: { ownerId: true },
  });
  if (store?.ownerId === userId) return true;

  const staffRecord = await prisma.staff.findUnique({
    where: { storeId_userId: { storeId, userId } },
    select: { role: true, isActive: true },
  });
  if (!staffRecord || !staffRecord.isActive) return false;
  if (staffRecord.role === 'OWNER') return true;

  const legacyKeyByPermission = new Map<string, string>();
  for (const perm of requiredPermissions) {
    const legacyKey = legacyPermissionKeyFor(perm);
    if (legacyKey) legacyKeyByPermission.set(perm, legacyKey);
  }
  const dbPermissionKeys = [...new Set(legacyKeyByPermission.values())];

  const rolePermissions = dbPermissionKeys.length
    ? await prisma.rolePermission.findMany({
        where: {
          storeId,
          role: staffRecord.role,
          permission: { in: dbPermissionKeys },
        },
        select: { permission: true, isGranted: true },
      })
    : [];

  const dbAllow = new Set(
    rolePermissions.filter((rp) => rp.isGranted).map((rp) => rp.permission),
  );
  const dbDeny = new Set(
    rolePermissions.filter((rp) => !rp.isGranted).map((rp) => rp.permission),
  );

  return requiredPermissions.every((perm) => {
    const legacyKey = legacyKeyByPermission.get(perm);
    if (legacyKey) {
      if (dbDeny.has(legacyKey)) return false;
      if (dbAllow.has(legacyKey)) return true;
    }
    return hasDefaultPermission(staffRecord.role, perm);
  });
}
