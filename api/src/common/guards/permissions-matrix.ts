import { StaffRole } from '@prisma/client';

/**
 * Default permission matrix used by PermissionsGuard when no role-specific
 * rows exist in the RolePermission table for a given store. The matrix
 * lists the set of permissions that each non-owner role is allowed to
 * exercise out of the box.
 *
 * OWNER always passes and is therefore not listed here.
 *
 * Permissions are lower-case dotted strings of the form `resource.action`.
 * Controllers opt into enforcement by decorating a handler with
 * `@Permissions('resource.action')`.
 *
 * To change the defaults for a store, insert explicit rows into the
 * RolePermission table (the DB wins over this matrix).
 */
export const DEFAULT_PERMISSIONS: Record<StaffRole, readonly string[]> = {
  OWNER: [], // OWNER short-circuits to true before the matrix is consulted.
  ADMIN: [
    // ADMIN can do everything except billing / owner-only settings.
    'staff.manage',
    'store.manage',
    'roles.manage',
    'products.manage',
    'products.delete',
    'products.viewProfitability',
    'categories.manage',
    'customers.manage',
    'suppliers.manage',
    'sales.manage',
    'sales.refund',
    'shifts.manage',
    'payroll.manage',
    'payroll.pay',
    'expenses.write',
    'zakat.manage',
    'reports.view',
    // Bug #21 (2026-05-10 matrix probe): ADMIN was missing the four
    // operational write permissions below. The "ADMIN can do everything
    // except billing" intent was undermined — admins couldn't create
    // discounts, run inventory counts, manage deliveries, or create
    // investments. All four added to the default matrix.
    'discounts.write',
    'inventory.write',
    'deliveries.write',
    'investments.write',
  ],
  CASHIER: [
    // POS cashier — only runs the till, no management.
    'products.view',
    'categories.view',
    'customers.view',
    'customers.manage', // walk-in customer creation happens at the POS
    'sales.manage',
    'shifts.open',
    'shifts.close',
  ],
  WAREHOUSE: [
    // Stock / supplier operations; no money movement.
    'products.view',
    'products.manage',
    'categories.view',
    'categories.manage',
    'suppliers.view',
    'suppliers.manage',
    'stock.manage',
    // Bug #22 (2026-05-10 matrix probe): WAREHOUSE literally counts
    // stock — they are the role that runs inventory cycles. Was
    // returning 403 because `inventory.write` was missing from the
    // matrix.
    'inventory.write',
    // Receiving deliveries from suppliers is part of the warehouse
    // workflow too.
    'deliveries.write',
  ],
};

/**
 * True iff `role` is allowed `permission` by the default matrix. Always
 * returns false for permissions that are not in the matrix at all — callers
 * should treat that as "deny by default" once they have already checked
 * explicit DB rows.
 */
export function hasDefaultPermission(
  role: StaffRole,
  permission: string,
): boolean {
  return (DEFAULT_PERMISSIONS[role] ?? []).includes(permission);
}

/**
 * BE-P1-011 (QA sweep, 2026-07): RolesService/RolePermission persist staff
 * role overrides under a legacy snake_case vocabulary
 * (`manage_products`, `add_expenses`, ...) that predates the dotted
 * `resource.action` vocabulary PermissionsGuard actually enforces
 * (`products.manage`, `expenses.write`, ...). The two never intersected,
 * so revoking/granting a permission via `PUT /stores/:id/roles/:role/permissions`
 * silently had zero effect on route access — the guard's DB lookup was
 * always querying for keys that could never match what was stored.
 *
 * Rather than rename the legacy vocabulary (RolesService's DTO/API shape
 * is the roles-management contract and touches other call sites), this
 * table bridges the two: it maps a dotted permission consulted by
 * @Permissions(...) to the legacy snake_case key RolesService actually
 * writes to RolePermission.permission for the same real-world action, so
 * PermissionsGuard can query the DB the override was actually written to.
 *
 * Only include a mapping here when the legacy default (RolesService's
 * seed DEFAULT_PERMISSIONS) and this file's DEFAULT_PERMISSIONS already
 * agree for every role — i.e. the two vocabularies describe the exact
 * same permission. `manage_staff` is deliberately NOT mapped to
 * `staff.manage`: RolesService seeds ADMIN.manage_staff = false while this
 * matrix grants ADMIN `staff.manage` = true, a pre-existing disagreement
 * between the two systems. Bridging it would make the very first
 * `GET /stores/:id/roles` call silently seed a DB row that revokes
 * `staff.manage` from every ADMIN, the moment anyone opens the Roles UI —
 * a behavior change well outside this fix. Left as a follow-up.
 * `view_sales`, `view_profit`, and `change_prices` also have no guarded
 * route counterpart today, so they stay unmapped too.
 */
export const LEGACY_PERMISSION_ALIASES: Record<string, string> = {
  'products.manage': 'manage_products',
  'customers.manage': 'manage_customers',
  'expenses.write': 'add_expenses',
  'reports.view': 'view_reports',
  'sales.manage': 'create_sales',
  'sales.refund': 'cancel_sales',
};

/** Legacy snake_case RolePermission key for a dotted permission, if any. */
export function legacyPermissionKeyFor(permission: string): string | undefined {
  return LEGACY_PERMISSION_ALIASES[permission];
}
