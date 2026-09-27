import 'reflect-metadata';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake() {
  const users = new Map<string, any>();

  return {
    _users: users,
    user: {
      findUnique: jest.fn(
        async ({ where }: any) => users.get(where.id) ?? null,
      ),
      update: jest.fn(async ({ where, data }: any) => {
        const u = users.get(where.id);
        if (!u) throw new Error('not found');
        Object.assign(u, data);
        return { id: u.id, isActive: u.isActive };
      }),
      count: jest.fn(async ({ where }: any) => {
        return [...users.values()].filter((u) => {
          if (where?.isAdmin !== undefined && u.isAdmin !== where.isAdmin)
            return false;
          if (where?.isActive !== undefined && u.isActive !== where.isActive)
            return false;
          if (where?.id?.not && u.id === where.id.not) return false;
          return true;
        }).length;
      }),
    },
  } as any;
}

describe('AdminService.deleteUser — last-admin guard', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;

  const seedUser = (overrides: Partial<any> = {}) => {
    const row = {
      id: overrides.id ?? 'user-1',
      phone: '+992900000001',
      isAdmin: false,
      isActive: true,
      ...overrides,
    };
    prisma._users.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: {} },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('should throw NotFoundException when the user does not exist', async () => {
    await expect(service.deleteUser('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('should throw ForbiddenException when deleting the last remaining admin', async () => {
    seedUser({ id: 'admin-1', isAdmin: true });

    await expect(service.deleteUser('admin-1')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma._users.get('admin-1')!.isActive).toBe(true);
  });

  it('should not count an already-inactive admin as a remaining admin', async () => {
    seedUser({ id: 'admin-1', isAdmin: true });
    seedUser({ id: 'admin-2', isAdmin: true, isActive: false });

    await expect(service.deleteUser('admin-1')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('should allow deleting an admin when another active admin remains', async () => {
    seedUser({ id: 'admin-1', isAdmin: true });
    seedUser({ id: 'admin-2', isAdmin: true });

    await service.deleteUser('admin-1');

    expect(prisma._users.get('admin-1')!.isActive).toBe(false);
  });

  it('should allow deleting a non-admin user regardless of how many admins exist', async () => {
    seedUser({ id: 'user-1', isAdmin: false });

    await service.deleteUser('user-1');

    expect(prisma._users.get('user-1')!.isActive).toBe(false);
  });
});
