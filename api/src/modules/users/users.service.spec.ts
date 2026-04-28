import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UsersService } from './users.service';
import { PrismaService } from '../../prisma/prisma.service';

// Behavioral fake: Map-backed user storage. Asserts persisted state, not
// implementation detail of which prisma method got called with what args.
function makePrismaFake() {
  type UserRow = {
    id: string;
    phone: string;
    name: string | null;
    email: string | null;
    avatar: string | null;
    isAdmin: boolean;
    password: string;
    createdAt: Date;
  };

  const users = new Map<string, UserRow>();

  return {
    _users: users,
    user: {
      findUnique: jest.fn(async ({ where, select }: any) => {
        const row = users.get(where.id);
        if (!row) return null;
        if (!select) return { ...row };
        const out: any = {};
        for (const k of Object.keys(select)) {
          if (select[k]) out[k] = (row as any)[k];
        }
        return out;
      }),
      update: jest.fn(async ({ where, data, select }: any) => {
        const row = users.get(where.id);
        if (!row) throw new Error('not found');
        Object.assign(row, data);
        if (!select) return { ...row };
        const out: any = {};
        for (const k of Object.keys(select)) {
          if (select[k]) out[k] = (row as any)[k];
        }
        return out;
      }),
    },
  };
}

describe('UsersService', () => {
  let service: UsersService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(UsersService);
  });

  const seedUser = async (overrides: Partial<any> = {}) => {
    const passwordHash = await bcrypt.hash(
      overrides.plainPassword ?? 'oldpass123',
      10,
    );
    const row = {
      id: 'user-1',
      phone: '+992900000001',
      name: 'Alice',
      email: 'alice@example.com',
      avatar: null,
      isAdmin: false,
      password: passwordHash,
      createdAt: new Date('2026-04-01'),
      ...overrides,
    };
    delete (row as any).plainPassword;
    prisma._users.set(row.id, row);
    return row;
  };

  describe('getProfile', () => {
    it('should return profile fields without password when user exists', async () => {
      await seedUser();
      const result = await service.getProfile('user-1');
      expect(result).toMatchObject({
        id: 'user-1',
        phone: '+992900000001',
        name: 'Alice',
        email: 'alice@example.com',
      });
      expect((result as any).password).toBeUndefined();
    });

    it('should throw NotFoundException when user id does not exist', async () => {
      await expect(service.getProfile('missing')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('updateProfile', () => {
    it('should persist updated name and not return password when updating profile', async () => {
      await seedUser();
      const result = await service.updateProfile('user-1', {
        name: 'Alice Updated',
      } as any);
      expect(result.name).toBe('Alice Updated');
      expect((result as any).password).toBeUndefined();
      expect(prisma._users.get('user-1')!.name).toBe('Alice Updated');
    });
  });

  describe('changePassword', () => {
    it('should hash new password and persist update when current password matches', async () => {
      await seedUser({ plainPassword: 'oldpass123' });
      const before = prisma._users.get('user-1')!.password;

      const result = await service.changePassword(
        'user-1',
        'oldpass123',
        'brandNewPass456',
      );

      expect(result).toEqual({ message: 'Password changed successfully' });
      const after = prisma._users.get('user-1')!.password;
      expect(after).not.toBe(before);
      // Newly stored hash must verify against the new plaintext, not the old.
      expect(await bcrypt.compare('brandNewPass456', after)).toBe(true);
      expect(await bcrypt.compare('oldpass123', after)).toBe(false);
    });

    it('should throw BadRequestException and NOT mutate password when current password is incorrect', async () => {
      await seedUser({ plainPassword: 'oldpass123' });
      const before = prisma._users.get('user-1')!.password;

      await expect(
        service.changePassword('user-1', 'wrongpass', 'brandNewPass456'),
      ).rejects.toBeInstanceOf(BadRequestException);

      // Critical security invariant: failed attempt must leave hash untouched.
      expect(prisma._users.get('user-1')!.password).toBe(before);
    });

    it('should throw NotFoundException when changing password for unknown user', async () => {
      await expect(
        service.changePassword('does-not-exist', 'x', 'y'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
