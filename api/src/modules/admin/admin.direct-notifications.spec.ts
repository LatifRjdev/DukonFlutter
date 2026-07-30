import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';
import { SendDirectNotificationDto } from './dto/send-direct-notification.dto';

function makePrismaFake() {
  return {
    store: {
      findFirst: jest.fn(async () => null as any),
    },
  };
}

describe('AdminService — sendDirectNotification', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock; sendToStoreUsers: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = {
      sendPush: jest.fn(async () => undefined),
      sendToStoreUsers: jest.fn(async () => undefined),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('sends to every store user when storeId is given', async () => {
    await service.sendDirectNotification({
      storeId: 's1',
      title: 'Заголовок',
      body: 'Текст',
    } as any);

    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      's1',
      'Заголовок',
      'Текст',
      'ADMIN_DIRECT',
    );
    expect(notifications.sendPush).not.toHaveBeenCalled();
  });

  it('resolves the user oldest owned store and sends push when userId is given', async () => {
    (prisma.store.findFirst as jest.Mock).mockResolvedValue({
      id: 'store-primary',
    });

    await service.sendDirectNotification({
      userId: 'u1',
      title: 'Заголовок',
      body: 'Текст',
    } as any);

    expect(prisma.store.findFirst).toHaveBeenCalledWith({
      where: { ownerId: 'u1' },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });
    expect(notifications.sendPush).toHaveBeenCalledWith(
      'u1',
      'Заголовок',
      'Текст',
      'ADMIN_DIRECT',
      'store-primary',
    );
  });

  it('throws NotFoundException when targeted user owns no store', async () => {
    (prisma.store.findFirst as jest.Mock).mockResolvedValue(null);

    await expect(
      service.sendDirectNotification({
        userId: 'u-no-store',
        title: 'Заголовок',
        body: 'Текст',
      } as any),
    ).rejects.toThrow(NotFoundException);
  });
});

describe('SendDirectNotificationDto validation', () => {
  it('fails validation when neither userId nor storeId is set', async () => {
    const dto = plainToInstance(SendDirectNotificationDto, {
      title: 'Заголовок',
      body: 'Текст',
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
  });

  it('fails validation when both userId and storeId are set', async () => {
    const dto = plainToInstance(SendDirectNotificationDto, {
      userId: 'u1',
      storeId: 's1',
      title: 'Заголовок',
      body: 'Текст',
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
  });

  it('passes validation when only userId is set', async () => {
    const dto = plainToInstance(SendDirectNotificationDto, {
      userId: 'u1',
      title: 'Заголовок',
      body: 'Текст',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('passes validation when only storeId is set', async () => {
    const dto = plainToInstance(SendDirectNotificationDto, {
      storeId: 's1',
      title: 'Заголовок',
      body: 'Текст',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });
});
