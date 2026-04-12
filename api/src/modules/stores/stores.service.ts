import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateStoreDto } from './dto/create-store.dto';
import { UpdateStoreDto } from './dto/update-store.dto';
import { ReceiptTemplateDto } from './dto/receipt-template.dto';

@Injectable()
export class StoresService {
  constructor(private prisma: PrismaService) {}

  async create(ownerId: string, dto: CreateStoreDto) {
    const now = new Date();
    const trialEnd = new Date(now);
    trialEnd.setDate(trialEnd.getDate() + 14);

    return this.prisma.store.create({
      data: {
        owner: { connect: { id: ownerId } },
        name: dto.name,
        category: dto.category as any,
        currency: (dto.currency as any) || 'TJS',
        address: dto.address,
        phone: dto.phone,
        subscription: {
          create: {
            plan: 'START',
            status: 'TRIAL',
            trialEndsAt: trialEnd,
            currentPeriodStart: now,
            currentPeriodEnd: trialEnd,
          },
        },
        staff: {
          create: {
            user: { connect: { id: ownerId } },
            role: 'OWNER',
          },
        },
      },
      include: {
        subscription: true,
      },
    });
  }

  async findAll(ownerId: string) {
    return this.prisma.store.findMany({
      where: { ownerId, isActive: true },
      include: { subscription: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const store = await this.prisma.store.findUnique({
      where: { id },
      include: { subscription: true },
    });
    if (!store) throw new NotFoundException('Store not found');
    return store;
  }

  async update(id: string, dto: UpdateStoreDto) {
    return this.prisma.store.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.category && { category: dto.category as any }),
        ...(dto.currency && { currency: dto.currency as any }),
        ...(dto.address !== undefined && { address: dto.address }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
      },
      include: { subscription: true },
    });
  }

  async getReceiptTemplate(storeId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { settings: true },
    });
    if (!store) throw new NotFoundException('Store not found');

    const settings = (store.settings as Record<string, any>) ?? {};
    const template = settings['receiptTemplate'] ?? this.defaultReceiptTemplate();
    return { receiptTemplate: template };
  }

  async updateReceiptTemplate(storeId: string, dto: ReceiptTemplateDto) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { settings: true },
    });
    if (!store) throw new NotFoundException('Store not found');

    const settings = (store.settings as Record<string, any>) ?? {};
    const existing = settings['receiptTemplate'] ?? this.defaultReceiptTemplate();
    const updated = this.prisma.store.update({
      where: { id: storeId },
      data: {
        settings: {
          ...settings,
          receiptTemplate: { ...existing, ...dto },
        },
      },
      select: { settings: true },
    });

    return updated.then((s) => ({
      receiptTemplate: (s.settings as Record<string, any>)['receiptTemplate'],
    }));
  }

  private defaultReceiptTemplate() {
    return {
      storeName: '',
      address: '',
      phone: '',
      footer: 'Thank you for your purchase!',
      showLogo: true,
      showBarcode: true,
      header: '',
      taxId: '',
    };
  }
}
