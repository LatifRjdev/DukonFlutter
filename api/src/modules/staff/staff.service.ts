import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { Prisma, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';

@Injectable()
export class StaffService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateStaffDto) {
    // Look up user by phone
    let user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    // If user not found, create with temporary password = phone
    if (!user) {
      const hashedPassword = await bcrypt.hash(dto.phone, 12);
      user = await this.prisma.user.create({
        data: {
          phone: dto.phone,
          name: dto.name,
          password: hashedPassword,
        },
      });
    }

    // Check if staff record already exists for this user in this store
    const existing = await this.prisma.staff.findUnique({
      where: { storeId_userId: { storeId, userId: user.id } },
    });
    if (existing) {
      throw new ConflictException('This user is already a staff member of this store');
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
    await this.findOne(storeId, id);

    return this.prisma.staff.update({
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
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.staff.update({
      where: { id },
      data: { isActive: false },
    });
  }
}
