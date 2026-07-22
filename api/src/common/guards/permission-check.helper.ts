import { PrismaService } from '../../prisma/prisma.service';
import {
  hasDefaultPermission,
  legacyPermissionKeyFor,
} from './permissions-matrix';

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
 * implementation — see permissions-matrix.ts for why the DB-override
 * translation (legacyPermissionKeyFor) exists and the alias table itself.
 *
 * Call once per request to gate a whole response, not per row inside a
 * list-serialization loop — each call does up to 3 sequential DB round
 * trips (store, staff, rolePermission).
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

  return requiredPermissions.every((perm) => {
    const legacyKey = legacyKeyByPermission.get(perm);
    if (legacyKey) {
      if (dbDeny.has(legacyKey)) return false;
      if (dbAllow.has(legacyKey)) return true;
    }
    // Not mentioned in DB (or not bridged to a legacy key) → consult
    // the hardcoded default matrix.
    return hasDefaultPermission(staffRecord.role, perm);
  });
}
