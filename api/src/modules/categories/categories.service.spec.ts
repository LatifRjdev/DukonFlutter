import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { PrismaService } from '../../prisma/prisma.service';

type CategoryRow = {
  id: string;
  storeId: string;
  name: string;
  icon: string | null;
  color: string | null;
  sortOrder: number;
  parentId: string | null;
  productCount: number; // simulated _count.products
};

function makePrismaFake() {
  const cats = new Map<string, CategoryRow>();
  let seq = 0;

  const withCount = (c: CategoryRow) => ({
    ...c,
    _count: { products: c.productCount },
  });

  const category = {
    create: jest.fn(async ({ data, include }: any) => {
      void include;
      const id = `cat-${++seq}`;
      const row: CategoryRow = {
        id,
        storeId: data.storeId,
        name: data.name,
        icon: data.icon ?? null,
        color: data.color ?? null,
        sortOrder: data.sortOrder ?? 0,
        parentId: data.parentId ?? null,
        productCount: 0,
      };
      cats.set(id, row);
      return withCount(row);
    }),
    findMany: jest.fn(async ({ where }: any) => {
      const list = Array.from(cats.values()).filter((c) =>
        where?.storeId ? c.storeId === where.storeId : true,
      );
      list.sort((a, b) => a.sortOrder - b.sortOrder);
      return list.map(withCount);
    }),
    findUnique: jest.fn(async ({ where }: any) => {
      const c = cats.get(where.id);
      return c ? withCount(c) : null;
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const c = cats.get(where.id);
      if (!c) throw new Error('Not found');
      Object.assign(c, data);
      return withCount(c);
    }),
    delete: jest.fn(async ({ where }: any) => {
      const c = cats.get(where.id);
      if (!c) throw new Error('Not found');
      cats.delete(where.id);
      return c;
    }),
  };

  return { category, __cats: cats } as any;
}

describe('CategoriesService', () => {
  let service: CategoriesService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        CategoriesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(CategoriesService);
  });

  describe('create + findAll — storeId scoping', () => {
    it('should persist parentId so child can be linked to parent when hierarchy is provided', async () => {
      const parent = await service.create('store-A', { name: 'Drinks' });
      const child = await service.create('store-A', {
        name: 'Cold Drinks',
        parentId: parent.id,
      });
      expect(child.parentId).toBe(parent.id);
      expect(child.storeId).toBe('store-A');
    });

    it('should only return categories for the requested store when multiple stores exist', async () => {
      await service.create('store-A', { name: 'Drinks' });
      await service.create('store-A', { name: 'Snacks' });
      await service.create('store-B', { name: 'Tools' });

      const aOnly = await service.findAll('store-A');
      const bOnly = await service.findAll('store-B');

      expect(aOnly.map((c) => c.name).sort()).toEqual(['Drinks', 'Snacks']);
      expect(bOnly.map((c) => c.name)).toEqual(['Tools']);
    });
  });

  describe('findOne', () => {
    it('should throw NotFoundException when category does not exist', async () => {
      await expect(service.findOne('non-existent')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('remove — product-link guard', () => {
    it('should throw BadRequestException when category still has linked products', async () => {
      const cat = await service.create('store-A', { name: 'Drinks' });
      // Simulate products in the category via the fake
      prisma.__cats.get(cat.id).productCount = 3;

      await expect(service.remove(cat.id)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      // Category was NOT deleted
      expect(prisma.__cats.has(cat.id)).toBe(true);
    });

    it('should delete category when product count is zero', async () => {
      const cat = await service.create('store-A', { name: 'Empty' });
      await service.remove(cat.id);
      expect(prisma.__cats.has(cat.id)).toBe(false);
    });

    it('should throw NotFoundException when removing a non-existent category', async () => {
      await expect(service.remove('does-not-exist')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('update', () => {
    it('should update name and persist sortOrder when provided', async () => {
      const cat = await service.create('store-A', { name: 'Drinks' });
      const updated = await service.update(cat.id, {
        name: 'Beverages',
      } as any);
      expect(updated.name).toBe('Beverages');
    });
  });
});
