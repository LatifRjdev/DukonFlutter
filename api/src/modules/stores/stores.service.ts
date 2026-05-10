import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { CreateStoreDto } from './dto/create-store.dto';
import { UpdateStoreDto } from './dto/update-store.dto';
import { ReceiptTemplateDto } from './dto/receipt-template.dto';

@Injectable()
export class StoresService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditLogService,
  ) {}

  async create(ownerId: string, dto: CreateStoreDto) {
    const now = new Date();
    const trialEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

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
            plan: 'PREMIUM',
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

  async update(id: string, dto: UpdateStoreDto, actorId: string = 'system') {
    // F-MONEY-2: Sale rows store amounts as plain Decimals with no
    // currency column. If the merchant flips store currency from TJS
    // to USD after running sales, the historic numbers stay 5/10/100
    // but the UI re-labels them as USD — silently inflating every
    // historical figure by 10×. Block currency change once any sale
    // exists; an admin tool can do the explicit migration.
    if (dto.currency) {
      const current = await this.prisma.store.findUnique({
        where: { id },
        select: { currency: true },
      });
      if (current && current.currency !== dto.currency) {
        const saleCount = await this.prisma.sale.count({
          where: { storeId: id },
        });
        if (saleCount > 0) {
          throw new BadRequestException(
            'Currency cannot be changed once sales exist for this store. ' +
              'Contact support if you need a migration.',
          );
        }
      }
    }

    const result = await this.prisma.store.update({
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

    // D.3: audit currency changes specifically (other fields are
    // low-impact metadata).
    if (dto.currency) {
      void this.audit.record(actorId, 'store.currency_change', 'store', id, {
        newCurrency: dto.currency,
      });
    }

    return result;
  }

  async getReceiptTemplate(storeId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { settings: true },
    });
    if (!store) throw new NotFoundException('Store not found');

    const settings = (store.settings as Record<string, any>) ?? {};
    const template =
      settings['receiptTemplate'] ?? this.defaultReceiptTemplate();
    return { receiptTemplate: template };
  }

  async updateReceiptTemplate(storeId: string, dto: ReceiptTemplateDto) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { settings: true },
    });
    if (!store) throw new NotFoundException('Store not found');

    const settings = (store.settings as Record<string, any>) ?? {};
    const existing =
      settings['receiptTemplate'] ?? this.defaultReceiptTemplate();
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
