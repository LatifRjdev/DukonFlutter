import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { UpsertEcommerceIntegrationDto } from './dto/upsert-ecommerce-integration.dto';
import { UpsertProductMappingDto } from './dto/upsert-product-mapping.dto';

@ApiTags('Ecommerce')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)
@RequiresFeature('hasEcommerceIntegration')
@Controller('stores/:storeId/ecommerce')
export class EcommerceIntegrationController {
  constructor(
    private readonly integrationService: EcommerceIntegrationService,
  ) {}

  @Get('integration')
  @ApiOperation({
    summary: 'Get the current e-commerce integration settings, if configured',
  })
  getSettings(@Param('storeId') storeId: string) {
    return this.integrationService.getSettings(storeId);
  }

  @Put('integration')
  @ApiOperation({
    summary: 'Create or update the e-commerce integration settings',
  })
  upsertSettings(
    @Param('storeId') storeId: string,
    @Body() dto: UpsertEcommerceIntegrationDto,
  ) {
    return this.integrationService.upsertSettings(storeId, dto);
  }

  @Post('integration/regenerate-key')
  @ApiOperation({
    summary: 'Invalidate the current inbound API key and generate a new one',
  })
  regenerateApiKey(@Param('storeId') storeId: string) {
    return this.integrationService.regenerateApiKey(storeId);
  }

  @Get('mappings')
  @ApiOperation({
    summary: 'List all external-product-id mappings for this store',
  })
  listMappings(@Param('storeId') storeId: string) {
    return this.integrationService.listMappings(storeId);
  }

  @Put('mappings/:productId')
  @ApiOperation({
    summary:
      'Set (or clear, with an empty body) the external product id for a Dukon product',
  })
  upsertMapping(
    @Param('storeId') storeId: string,
    @Param('productId') productId: string,
    @Body() dto: UpsertProductMappingDto,
  ) {
    return this.integrationService.upsertMapping(
      storeId,
      productId,
      dto.externalProductId,
    );
  }
}
