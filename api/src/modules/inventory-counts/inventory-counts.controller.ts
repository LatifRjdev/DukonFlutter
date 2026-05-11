import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { InventoryCountsService } from './inventory-counts.service';
import { UpdateCountItemsDto } from './dto/update-count-items.dto';

@ApiTags('Inventory Counts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard, SubscriptionGuard)
// Deferred #3 (2026-05-11): all 4 routes require the same feature,
// so the decorator now lives on the class. SubscriptionGuard's
// reflector lookup (F.2 fix) reads handler-then-class metadata so
// this works as expected.
@RequiresFeature('hasInventory')
@Controller('stores/:storeId/inventory-counts')
export class InventoryCountsController {
  constructor(private inventoryCountsService: InventoryCountsService) {}

  // Every endpoint requires hasInventory. Without per-method decorators,
  // START tier could read/finalize counts that were created during a
  // trial-PREMIUM window after downgrading.
  @Post()
  @Permissions('inventory.write')
  @ApiOperation({
    summary:
      'Create a new inventory count session (loads all products with current stock)',
  })
  create(@Param('storeId') storeId: string) {
    return this.inventoryCountsService.create(storeId);
  }

  @Get(':id')
  @ApiOperation({
    summary:
      'Get inventory count session with items (includes product name, barcode)',
  })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.inventoryCountsService.findOne(storeId, id);
  }

  @Put(':id')
  @Permissions('inventory.write')
  @ApiOperation({
    summary: 'Update actual quantities for items in a count session (batch)',
  })
  updateItems(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateCountItemsDto,
  ) {
    return this.inventoryCountsService.updateItems(storeId, id, dto);
  }

  @Post(':id/apply')
  @Permissions('inventory.write')
  @ApiOperation({
    summary:
      'Finalize count: update product stock quantities and set status=COMPLETED',
  })
  apply(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.inventoryCountsService.apply(storeId, id);
  }
}
