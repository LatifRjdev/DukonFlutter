import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateCategoryDto) {
    return this.prisma.category.create({
      data: { storeId, ...dto },
      include: { _count: { select: { products: true } } },
    });
  }

  async findAll(storeId: string) {
    return this.prisma.category.findMany({
      where: { storeId },
      include: { _count: { select: { products: true } } },
      orderBy: { sortOrder: 'asc' },
    });
  }

  async findOne(storeId: string, id: string) {
    // BUG-CAT-IDOR: findOne/update/remove previously looked up by `id`
    // alone with no storeId filter, so any authenticated user with access
    // to ANY store (StoreAccessGuard only checks the :storeId in the
    // route, not that the target category belongs to it) could read,
    // modify, or delete a category belonging to a completely different
    // store just by guessing/obtaining its UUID.
    const category = await this.prisma.category.findFirst({
      where: { id, storeId },
      include: { _count: { select: { products: true } } },
    });
    if (!category) throw new NotFoundException('Category not found');
    return category;
  }

  async update(storeId: string, id: string, dto: UpdateCategoryDto) {
    await this.findOne(storeId, id);
    return this.prisma.category.update({
      where: { id },
      data: dto,
      include: { _count: { select: { products: true } } },
    });
  }

  async remove(storeId: string, id: string) {
    // F3.2: categories hard-delete by design — no soft-delete column on
    // the schema. Inconsistent with products+customers which soft-delete,
    // but categories are config not transactional data; once cleared,
    // they don't need archiving. The guard below blocks delete when
    // products still reference the category, preventing referential-
    // integrity errors at the DB layer.
    const category = await this.findOne(storeId, id);

    if (category._count.products > 0) {
      throw new BadRequestException(
        'Cannot delete category with products. Move or delete products first.',
      );
    }

    return this.prisma.category.delete({ where: { id } });
  }
}
