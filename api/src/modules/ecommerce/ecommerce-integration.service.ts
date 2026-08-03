import { Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { UpsertEcommerceIntegrationDto } from './dto/upsert-ecommerce-integration.dto';

@Injectable()
export class EcommerceIntegrationService {
  constructor(private prisma: PrismaService) {}

  private generateApiKey(): string {
    return randomBytes(24).toString('hex');
  }

  async getSettings(storeId: string) {
    return this.prisma.ecommerceIntegration.findUnique({ where: { storeId } });
  }

  async upsertSettings(storeId: string, dto: UpsertEcommerceIntegrationDto) {
    return this.prisma.ecommerceIntegration.upsert({
      where: { storeId },
      create: {
        storeId,
        apiKey: this.generateApiKey(),
        outboundWebhookUrl: dto.outboundWebhookUrl,
        enabled: dto.enabled ?? true,
      },
      update: {
        ...(dto.outboundWebhookUrl !== undefined && {
          outboundWebhookUrl: dto.outboundWebhookUrl,
        }),
        ...(dto.enabled !== undefined && { enabled: dto.enabled }),
      },
    });
  }

  async regenerateApiKey(storeId: string) {
    const existing = await this.prisma.ecommerceIntegration.findUnique({
      where: { storeId },
    });
    if (!existing) {
      throw new NotFoundException(
        'E-commerce integration not configured for this store',
      );
    }
    return this.prisma.ecommerceIntegration.update({
      where: { storeId },
      data: { apiKey: this.generateApiKey() },
    });
  }

  async listMappings(storeId: string) {
    return this.prisma.externalProductMapping.findMany({
      where: { storeId },
      include: { product: { select: { id: true, name: true, sku: true } } },
    });
  }

  async upsertMapping(
    storeId: string,
    productId: string,
    externalProductId?: string,
  ) {
    if (!externalProductId) {
      await this.prisma.externalProductMapping.deleteMany({
        where: { storeId, productId },
      });
      return null;
    }

    return this.prisma.externalProductMapping.upsert({
      where: {
        storeId_externalProductId: { storeId, externalProductId },
      },
      create: { storeId, productId, externalProductId },
      update: { productId },
    });
  }
}
