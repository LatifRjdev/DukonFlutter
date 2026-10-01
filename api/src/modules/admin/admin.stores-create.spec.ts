import 'reflect-metadata';
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

describe('AdminService.createStoreForOwner', () => {
  let service: AdminService;
  let storesService: { create: jest.Mock };
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(async ({ where }: any) =>
          where.id === 'user-1'
            ? { id: 'user-1', phone: '+992901234567', name: 'Али' }
            : null,
        ),
      },
    };
    // The real StoresService.create also makes the subscription and the OWNER
    // staff row; the fake returns the same shape so the assertions below are
    // about delegation, not about re-testing StoresService.
    storesService = {
      create: jest.fn(async (ownerId: string, dto: any) => ({
        id: 'store-1',
        ownerId,
        name: dto.name,
        category: dto.category,
        currency: dto.currency ?? 'TJS',
        subscription: {
          id: 'sub-1',
          storeId: 'store-1',
          plan: 'PREMIUM',
          status: 'TRIAL',
        },
      })),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: storesService },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('should create a store for an existing owner and return it with its subscription', async () => {
    const result = await service.createStoreForOwner({
      ownerId: 'user-1',
      name: 'Тестовый магазин',
      category: 'GROCERY',
    } as any);

    expect(result.id).toBe('store-1');
    expect(result.ownerId).toBe('user-1');
    // `subscription` is nullable on the Prisma return type, so reach for it
    // with `?.` — an absent subscription still fails these assertions.
    expect(result.subscription?.plan).toBe('PREMIUM');
    expect(result.subscription?.status).toBe('TRIAL');
  });

  it('should delegate to StoresService.create rather than writing the store itself', async () => {
    // Delegation is the point: StoresService.create is the single path that
    // also creates the subscription and the OWNER staff row. A second creation
    // path would silently skip those.
    await service.createStoreForOwner({
      ownerId: 'user-1',
      name: 'Тестовый магазин',
      category: 'GROCERY',
      currency: 'USD',
      address: 'Душанбе',
      phone: '+992900000000',
    } as any);

    expect(storesService.create).toHaveBeenCalledTimes(1);
    expect(storesService.create).toHaveBeenCalledWith('user-1', {
      name: 'Тестовый магазин',
      category: 'GROCERY',
      currency: 'USD',
      address: 'Душанбе',
      phone: '+992900000000',
    });
  });

  it('should throw NotFoundException when the owner does not exist', async () => {
    await expect(
      service.createStoreForOwner({
        ownerId: 'nope',
        name: 'Тестовый магазин',
        category: 'GROCERY',
      } as any),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(storesService.create).not.toHaveBeenCalled();
  });
});
