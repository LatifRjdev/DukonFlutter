import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    ecommerceIntegration: {
      findUnique: jest.fn(async () => null as any),
      upsert: jest.fn(async ({ create, update }: any) => ({
        id: 'ei-1',
        ...create,
        ...update,
      })),
      update: jest.fn(async ({ data }: any) => ({ id: 'ei-1', ...data })),
    },
    externalProductMapping: {
      findMany: jest.fn(async () => [] as any[]),
      upsert: jest.fn(async ({ create }: any) => ({ id: 'm-1', ...create })),
      deleteMany: jest.fn(async () => ({ count: 1 })),
    },
  };
}

describe('EcommerceIntegrationService', () => {
  let service: EcommerceIntegrationService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceIntegrationService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(EcommerceIntegrationService);
  });

  it('getSettings returns null when no integration exists yet', async () => {
    const result = await service.getSettings('store-1');
    expect(result).toBeNull();
  });

  it('upsertSettings creates a new integration with a generated apiKey on first call', async () => {
    const result = await service.upsertSettings('store-1', {
      outboundWebhookUrl: 'https://site.example/webhook',
      enabled: true,
    });

    expect(prisma.ecommerceIntegration.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: 'store-1' },
        create: expect.objectContaining({
          storeId: 'store-1',
          outboundWebhookUrl: 'https://site.example/webhook',
          enabled: true,
          apiKey: expect.any(String),
        }),
        update: expect.objectContaining({
          outboundWebhookUrl: 'https://site.example/webhook',
          enabled: true,
        }),
      }),
    );
    expect((result as any).apiKey).toBeDefined();
  });

  it('regenerateApiKey throws NotFoundException when no integration exists', async () => {
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue(
      null,
    );
    await expect(service.regenerateApiKey('store-1')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('regenerateApiKey replaces apiKey with a new value', async () => {
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      id: 'ei-1',
      apiKey: 'old-key',
    });

    await service.regenerateApiKey('store-1');

    const call = (prisma.ecommerceIntegration.update as jest.Mock).mock
      .calls[0][0];
    expect(call.where).toEqual({ storeId: 'store-1' });
    expect(call.data.apiKey).toBeDefined();
    expect(call.data.apiKey).not.toBe('old-key');
  });

  it('upsertMapping creates a mapping when externalProductId is non-empty', async () => {
    await service.upsertMapping('store-1', 'product-1', 'sku-123');

    expect(prisma.externalProductMapping.upsert).toHaveBeenCalledWith({
      where: {
        storeId_externalProductId: {
          storeId: 'store-1',
          externalProductId: 'sku-123',
        },
      },
      create: {
        storeId: 'store-1',
        productId: 'product-1',
        externalProductId: 'sku-123',
      },
      update: { productId: 'product-1' },
    });
  });

  it('upsertMapping deletes any existing mapping for the product when externalProductId is empty', async () => {
    await service.upsertMapping('store-1', 'product-1', '');

    expect(prisma.externalProductMapping.deleteMany).toHaveBeenCalledWith({
      where: { storeId: 'store-1', productId: 'product-1' },
    });
  });

  it('upsertSettings allows explicitly clearing outboundWebhookUrl by passing null', async () => {
    await service.upsertSettings('store-1', {
      outboundWebhookUrl: null,
    });

    expect(prisma.ecommerceIntegration.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: expect.objectContaining({
          outboundWebhookUrl: null,
        }),
      }),
    );
  });
});
