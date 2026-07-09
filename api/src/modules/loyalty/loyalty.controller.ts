import { Controller, Get, Put, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { LoyaltyService } from './loyalty.service';
import { UpdateLoyaltySettingsDto } from './dto/update-loyalty-settings.dto';

@ApiTags('Loyalty')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)
@RequiresFeature('hasLoyalty')
@Controller('stores/:storeId/loyalty')
export class LoyaltyController {
  constructor(private readonly loyaltyService: LoyaltyService) {}

  @Get('settings')
  @ApiOperation({ summary: 'Get loyalty program settings' })
  getSettings(@Param('storeId') storeId: string) {
    return this.loyaltyService.getSettings(storeId);
  }

  @Put('settings')
  @ApiOperation({ summary: 'Update loyalty program settings' })
  updateSettings(
    @Param('storeId') storeId: string,
    @Body() dto: UpdateLoyaltySettingsDto,
  ) {
    return this.loyaltyService.updateSettings(storeId, dto);
  }

  @Get('customers/:customerId/balance')
  @ApiOperation({
    summary: 'Get customer loyalty balance + last 20 transactions',
  })
  getCustomerBalance(
    @Param('storeId') storeId: string,
    @Param('customerId') customerId: string,
  ) {
    return this.loyaltyService.getCustomerBalance(storeId, customerId);
  }
}
