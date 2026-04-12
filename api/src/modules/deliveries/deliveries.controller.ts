import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { DeliveriesService } from './deliveries.service';
import { CreateDeliveryDto } from './dto/create-delivery.dto';
import { UpdateDeliveryStatusDto } from './dto/update-delivery-status.dto';
import { DeliveryQueryDto } from './dto/delivery-query.dto';

@ApiTags('Deliveries')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard, SubscriptionGuard)
@Controller('stores/:storeId/deliveries')
export class DeliveriesController {
  constructor(private deliveriesService: DeliveriesService) {}

  @Post()
  @Permissions('deliveries.write')
  @RequiresFeature('hasDelivery')
  @ApiOperation({ summary: 'Create a new delivery for a sale' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateDeliveryDto) {
    return this.deliveriesService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({
    summary:
      'List deliveries with optional filters (status, date range) and pagination',
  })
  findAll(@Param('storeId') storeId: string, @Query() query: DeliveryQueryDto) {
    return this.deliveriesService.findAll(storeId, query);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get delivery details including sale items and courier',
  })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.deliveriesService.findOne(storeId, id);
  }

  @Put(':id/status')
  @Permissions('deliveries.write')
  @ApiOperation({
    summary: 'Update delivery status (NEW→IN_TRANSIT→DELIVERED)',
  })
  updateStatus(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateDeliveryStatusDto,
  ) {
    return this.deliveriesService.updateStatus(storeId, id, dto);
  }
}
