import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { Prisma, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { assertWithinPlanLimit } from '../../common/guards/plan-limit.helper';

@Injectable()
export class StaffService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditLogService,
  ) {}

  async create(storeId: string, dto: CreateStaffDto) {
    // F2.1: enforce plan-limit. OWNER staff row is auto-created with the
    // store and counts toward the cap (so START's maxStaff=2 = owner + 1
    // cashier).
    const activeCount = await this.prisma.staff.count({
      where: { storeId, isActive: true },
    });
    await assertWithinPlanLimit(this.prisma, storeId, 'maxStaff', activeCount);

    // Look up user by phone
    let user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    // If user not found, auto-provision with an unguessable random password.
    // Previously this used dto.phone as the password, which allowed anyone
    // who knew the phone number to log in and take the account over
    // (BE-P0-001). The owner must now distribute a reset link or set the
    // password through a separate admin flow before the staff member can log
    // in. The raw password is never returned, so it is impossible to recover
    // — this is by design: closing the account-takeover hole is the priority.
    if (!user) {
      const randomPassword = randomBytes(32).toString('hex');
      const hashedPassword = await bcrypt.hash(randomPassword, 12);
      user = await this.prisma.user.create({
        data: {
          phone: dto.phone,
          name: dto.name,
          password: hashedPassword,
          isActive: false,
        },
      });
    }

    // Check if staff record already exists for this user in this store
    const existing = await this.prisma.staff.findUnique({
      where: { storeId_userId: { storeId, userId: user.id } },
    });
    if (existing) {
      throw new ConflictException(
        'This user is already a staff member of this store',
      );
    }

    // Create staff record
    const staff = await this.prisma.staff.create({
      data: {
        storeId,
        userId: user.id,
        role: dto.role as StaffRole,
        salary: dto.salary,
        commission: dto.commission,
      },
      include: {
        user: {
          select: { id: true, name: true, phone: true, avatar: true },
        },
      },
    });

    return staff;
  }

  async findAll(storeId: string, search?: string, role?: string) {
    const where: Prisma.StaffWhereInput = { storeId, isActive: true };

    if (role) {
      where.role = role as StaffRole;
    }

    if (search) {
      where.user = {
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { phone: { contains: search, mode: 'insensitive' } },
        ],
      };
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const staffList = await this.prisma.staff.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: { id: true, name: true, phone: true, avatar: true },
        },
        shifts: {
          where: { status: 'OPEN' },
          take: 1,
          select: { id: true, openedAt: true, status: true },
        },
        sales: {
          where: {
            createdAt: { gte: today, lt: tomorrow },
            status: 'COMPLETED',
          },
          select: { total: true },
        },
      },
    });

    return staffList.map((staff) => {
      const todaySalesCount = staff.sales.length;
      const todaySalesTotal = staff.sales.reduce(
        (sum, sale) => sum + Number(sale.total),
        0,
      );
      const isOnShift = staff.shifts.length > 0;
      const currentShift = staff.shifts[0] || null;

      const { sales, shifts, ...staffData } = staff;

      return {
        ...staffData,
        // F6.1: Staff doesn't have its own `name` column — it lives on
        // the related User. Surface a top-level `name` so a client that
        // reads `staff.name` (rather than `staff.user.name`) doesn't
        // see null. Same for `phone` for symmetry.
        name: staff.user?.name ?? null,
        phone: staff.user?.phone ?? null,
        isOnShift,
        currentShift,
        todaySalesCount,
        todaySalesTotal,
      };
    });
  }

  async findOne(storeId: string, id: string) {
    const staff = await this.prisma.staff.findFirst({
      where: { id, storeId },
      include: {
        user: {
          select: { id: true, name: true, phone: true, avatar: true },
        },
      },
    });
    if (!staff) throw new NotFoundException('Staff member not found');
    return staff;
  }

  async update(storeId: string, id: string, dto: UpdateStaffDto) {
    const before = await this.findOne(storeId, id);

    const updated = await this.prisma.staff.update({
      where: { id },
      data: {
        role: dto.role ? (dto.role as StaffRole) : undefined,
        salary: dto.salary,
        commission: dto.commission,
      },
      include: {
        user: {
          select: { id: true, name: true, phone: true, avatar: true },
        },
      },
    });

    // Deferred #2: audit any role change separately from salary tweaks
    // because role escalations carry security weight.
    if (dto.role && before.role !== dto.role) {
      void this.audit.record('system', 'staff.role_change', 'staff', id, {
        from: before.role,
        to: dto.role,
        storeId,
      });
    }

    return updated;
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.staff.update({
      where: { id },
      data: { isActive: false },
    });
  }
}
