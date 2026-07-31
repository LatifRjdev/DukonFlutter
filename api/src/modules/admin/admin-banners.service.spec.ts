import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake() {
  return {
    banner: {
      create: jest.fn(async ({ data }: any) => ({ id: 'b1', ...data })),
      findMany: jest.fn(async () => [] as any[]),
      findUnique: jest.fn(async ({ where }: any) => ({ id: where.id })),
      update: jest.fn(async ({ where, data }: any) => ({
        id: where.id,
        ...data,
      })),
    },
  };
}

describe('AdminService — banners', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('createBanner persists the row as given', async () => {
    const dto = {
      title: 'Скидка',
      body: '20% на все товары',
      targetPlan: 'PREMIUM' as const,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    };

    const result = await service.createBanner(dto as any);

    expect(prisma.banner.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        title: 'Скидка',
        body: '20% на все товары',
        targetPlan: 'PREMIUM',
      }),
    });
    expect((result as any).id).toBe('b1');
  });

  it('listBanners returns all banners ordered by newest first', async () => {
    await service.listBanners();

    expect(prisma.banner.findMany).toHaveBeenCalledWith({
      orderBy: { createdAt: 'desc' },
    });
  });

  it('setBannerActive toggles the active flag', async () => {
    const result = await service.setBannerActive('b1', false);

    expect(prisma.banner.findUnique).toHaveBeenCalledWith({
      where: { id: 'b1' },
    });
    expect(prisma.banner.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { active: false },
    });
    expect((result as any).active).toBe(false);
  });

  it('setBannerActive throws NotFoundException for a missing id', async () => {
    (prisma.banner.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(service.setBannerActive('missing', true)).rejects.toThrow(
      NotFoundException,
    );
    expect(prisma.banner.update).not.toHaveBeenCalled();
  });
});
