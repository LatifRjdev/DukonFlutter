import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { StaffRole } from '@prisma/client';
import { UpdatePermissionsDto } from './dto/update-permissions.dto';

// The mobile Роли и права screen (app/lib/presentation/pages/roles/roles_page.dart,
// _allPermissions) renders toggles for a set of keys that only partially overlapped
// with this list, so saving any of the non-overlapping mobile keys 400'd with
// "Invalid permissions". Extended to the union of both lists so every mobile
// toggle can be saved. Note some of these keys (including several pre-existing
// ones like view_sales/view_profit/change_prices) aren't wired to real route
// enforcement yet — see api/src/common/guards/permissions-matrix.ts and its
// LEGACY_PERMISSION_ALIASES for which permissions actually gate access today.
const ALL_PERMISSIONS = [
  'view_sales',
  'create_sales',
  'cancel_sales',
  'view_profit',
  'change_prices',
  'manage_products',
  'add_expenses',
  'manage_customers',
  'manage_staff',
  'view_reports',
  'manage_sales',
  'manage_returns',
  'manage_expenses',
  'manage_suppliers',
  'manage_stock',
  'manage_debts',
  'manage_settings',
  'open_close_shift',
  'apply_discounts',
  'manage_payroll',
];

const DEFAULT_PERMISSIONS: Record<string, Record<string, boolean>> = {
  ADMIN: {
    view_sales: true,
    create_sales: true,
    cancel_sales: true,
    view_profit: true,
    change_prices: true,
    manage_products: true,
    add_expenses: true,
    manage_customers: true,
    manage_staff: false,
    view_reports: true,
    manage_sales: true,
    manage_returns: true,
    manage_expenses: true,
    manage_suppliers: true,
    manage_stock: true,
    manage_debts: true,
    manage_settings: false,
    open_close_shift: true,
    apply_discounts: true,
    manage_payroll: false,
  },
  CASHIER: {
    view_sales: true,
    create_sales: true,
    cancel_sales: false,
    view_profit: false,
    change_prices: false,
    manage_products: false,
    add_expenses: false,
    manage_customers: true,
    manage_staff: false,
    view_reports: false,
    manage_sales: true,
    manage_returns: false,
    manage_expenses: false,
    manage_suppliers: false,
    manage_stock: false,
    manage_debts: true,
    manage_settings: false,
    open_close_shift: true,
    apply_discounts: true,
    manage_payroll: false,
  },
  WAREHOUSE: {
    view_sales: false,
    create_sales: false,
    cancel_sales: false,
    view_profit: false,
    change_prices: false,
    manage_products: true,
    add_expenses: false,
    manage_customers: false,
    manage_staff: false,
    view_reports: false,
    manage_sales: false,
    manage_returns: false,
    manage_expenses: false,
    manage_suppliers: true,
    manage_stock: true,
    manage_debts: false,
    manage_settings: false,
    open_close_shift: false,
    apply_discounts: false,
    manage_payroll: false,
  },
};

const CONFIGURABLE_ROLES: StaffRole[] = ['ADMIN', 'CASHIER', 'WAREHOUSE'];

@Injectable()
export class RolesService {
  constructor(private prisma: PrismaService) {}

  async getAllRoles(storeId: string) {
    await this.seedIfNeeded(storeId);

    const permissions = await this.prisma.rolePermission.findMany({
      where: { storeId },
      orderBy: [{ role: 'asc' }, { permission: 'asc' }],
    });

    const rolesMap: Record<string, Record<string, boolean>> = {};

    // OWNER always has all permissions (not stored in DB)
    rolesMap['OWNER'] = {};
    for (const perm of ALL_PERMISSIONS) {
      rolesMap['OWNER'][perm] = true;
    }

    // Build map from DB records
    for (const rp of permissions) {
      if (!rolesMap[rp.role]) {
        rolesMap[rp.role] = {};
      }
      rolesMap[rp.role][rp.permission] = rp.isGranted;
    }

    return Object.entries(rolesMap).map(([role, perms]) => ({
      role,
      permissions: perms,
    }));
  }

  async getRolePermissions(storeId: string, role: string) {
    this.validateRole(role);

    if (role === 'OWNER') {
      const perms: Record<string, boolean> = {};
      for (const perm of ALL_PERMISSIONS) {
        perms[perm] = true;
      }
      return { role: 'OWNER', permissions: perms };
    }

    await this.seedIfNeeded(storeId);

    const records = await this.prisma.rolePermission.findMany({
      where: { storeId, role: role as StaffRole },
      orderBy: { permission: 'asc' },
    });

    const perms: Record<string, boolean> = {};
    for (const r of records) {
      perms[r.permission] = r.isGranted;
    }

    return { role, permissions: perms };
  }

  async updateRolePermissions(storeId: string, role: string, dto: UpdatePermissionsDto) {
    this.validateRole(role);

    if (role === 'OWNER') {
      throw new BadRequestException('Cannot modify OWNER permissions');
    }

    // Validate permission names
    const invalidPerms = Object.keys(dto.permissions).filter(
      (p) => !ALL_PERMISSIONS.includes(p),
    );
    if (invalidPerms.length > 0) {
      throw new BadRequestException(`Invalid permissions: ${invalidPerms.join(', ')}`);
    }

    await this.seedIfNeeded(storeId);

    // Upsert each permission
    const updates = Object.entries(dto.permissions).map(([permission, isGranted]) =>
      this.prisma.rolePermission.upsert({
        where: {
          storeId_role_permission: {
            storeId,
            role: role as StaffRole,
            permission,
          },
        },
        update: { isGranted },
        create: {
          storeId,
          role: role as StaffRole,
          permission,
          isGranted,
        },
      }),
    );

    await this.prisma.$transaction(updates);

    return this.getRolePermissions(storeId, role);
  }

  private async seedIfNeeded(storeId: string) {
    const count = await this.prisma.rolePermission.count({
      where: { storeId },
    });

    if (count > 0) {
      return;
    }

    const data: { storeId: string; role: StaffRole; permission: string; isGranted: boolean }[] = [];

    for (const role of CONFIGURABLE_ROLES) {
      for (const permission of ALL_PERMISSIONS) {
        data.push({
          storeId,
          role,
          permission,
          isGranted: DEFAULT_PERMISSIONS[role][permission],
        });
      }
    }

    await this.prisma.rolePermission.createMany({ data });
  }

  private validateRole(role: string) {
    const validRoles = ['OWNER', ...CONFIGURABLE_ROLES];
    if (!validRoles.includes(role as StaffRole)) {
      throw new BadRequestException(
        `Invalid role: ${role}. Valid roles: ${validRoles.join(', ')}`,
      );
    }
  }
}
