import 'reflect-metadata';
import { ConflictException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake() {
  const users = new Map<string, any>();
  let userSeq = 0;

  return {
    _users: users,
    user: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.phone) {
          return [...users.values()].find((u) => u.phone === where.phone) ?? null;
        }
        return users.get(where.id) ?? null;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `user-${++userSeq}`;
        const row = {
          id,
          phone: data.phone,
          name: data.name,
          email: data.email ?? null,
          isAdmin: false,
          isActive: true,
          password: data.password,
          createdAt: new Date(),
        };
        users.set(id, row);
        return row;
      }),
    },
    $transaction: jest.fn(async (fn: any) => fn({
      user: {
        create: jest.fn(async ({ data }: any) => {
          const id = `user-${++userSeq}`;
          const row = {
            id,
            phone: data.phone,
            name: data.name,
            email: data.email ?? null,
            isAdmin: false,
            isActive: true,
            password: data.password,
            createdAt: new Date(),
          };
          users.set(id, row);
          return row;
        }),
      },
    })),
  } as any;
}

describe('AdminService.createUserManually', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let storesService: { create: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    storesService = {
      create: jest.fn(async (ownerId: string, dto: any) => ({
        id: 'store-1',
        ownerId,
        name: dto.name,
        category: dto.category,
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

  it('should create a user with the admin-provided password and not generate one', async () => {
    const result = await service.createUserManually({
      name: 'Али',
      phone: '+992901234567',
      password: 'CorrectHorseBatteryStaple8',
    } as any);

    expect(result.user.phone).toBe('+992901234567');
    expect(result.generatedPassword).toBeNull();
    expect(result.store).toBeNull();
    expect(storesService.create).not.toHaveBeenCalled();
  });

  it('should generate a strong password and return it once when none is provided', async () => {
    const result = await service.createUserManually({
      name: 'Зарина',
      phone: '+992901234568',
    } as any);

    expect(typeof result.generatedPassword).toBe('string');
    expect(result.generatedPassword!.length).toBeGreaterThanOrEqual(12);
  });

  it('should throw ConflictException when the phone is already taken', async () => {
    await service.createUserManually({
      name: 'Первый',
      phone: '+992901234569',
      password: 'CorrectHorseBatteryStaple8',
    } as any);

    await expect(
      service.createUserManually({
        name: 'Второй',
        phone: '+992901234569',
        password: 'AnotherStrongOne9',
      } as any),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('should create a store via StoresService.create when createStore is true, inside the same transaction', async () => {
    const result = await service.createUserManually({
      name: 'Владелец',
      phone: '+992901234570',
      password: 'CorrectHorseBatteryStaple8',
      createStore: true,
      storeName: 'Мой магазин',
      storeCategory: 'GROCERY',
    } as any);

    expect(storesService.create).toHaveBeenCalledTimes(1);
    const [ownerIdArg, dtoArg, txArg] = storesService.create.mock.calls[0];
    expect(ownerIdArg).toBe(result.user.id);
    expect(dtoArg.name).toBe('Мой магазин');
    expect(dtoArg.category).toBe('GROCERY');
    // Proves the transaction client (not the top-level prisma) was passed through.
    expect(txArg).toBeDefined();
    expect(txArg).not.toBe(prisma);
    expect(result.store).toEqual({ id: 'store-1', name: 'Мой магазин' });
  });

  it('should not include the raw or hashed password anywhere in the returned user object', async () => {
    const result = await service.createUserManually({
      name: 'Секьюр',
      phone: '+992901234571',
      password: 'CorrectHorseBatteryStaple8',
    } as any);

    expect(result.user).not.toHaveProperty('password');
  });
});
