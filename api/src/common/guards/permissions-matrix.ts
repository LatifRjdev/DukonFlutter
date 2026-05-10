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
