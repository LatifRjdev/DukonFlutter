import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { ImportProductsService } from './import-products.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('ImportProductsService — parseFile guard', () => {
  let service: ImportProductsService;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        ImportProductsService,
        { provide: PrismaService, useValue: {} },
      ],
    }).compile();
    service = moduleRef.get(ImportProductsService);
  });

  it('should throw BadRequestException when buffer is empty (zero bytes)', async () => {
    await expect(
      (service as any).parseFile(Buffer.alloc(0)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('should throw BadRequestException when buffer is null', async () => {
    await expect((service as any).parseFile(null)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('should include a descriptive message in the exception', async () => {
    await expect(
      (service as any).parseFile(Buffer.alloc(0)),
    ).rejects.toMatchObject({ message: 'Файл пустой или повреждён' });
  });
});
