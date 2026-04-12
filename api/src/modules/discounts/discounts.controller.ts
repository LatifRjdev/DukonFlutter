import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { DiscountsService } from './discounts.service';
import { CreateDiscountDto } from './dto/create-discount.dto';
import { UpdateDiscountDto } from './dto/update-discount.dto';
import { ApplicableDiscountQueryDto } from './dto/applicable-discount-query.dto';

@ApiTags('Discounts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/discounts')
export class DiscountsController {
  constructor(private discountsService: DiscountsService) {}

  @Post()
  @Permissions('discounts.write')
  @ApiOperation({ summary: 'Create discount' })
  create(
    @Param('storeId') storeId: string,
    @Body() dto: CreateDiscountDto,
  ) {
    return this.discountsService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List all discounts for store' })
  findAll(@Param('storeId') storeId: string) {
    return this.discountsService.findAll(storeId);
  }

  @Get('applicable')
  @ApiOperation({
    summary:
      'Find applicable discounts for current cart (filter by total, categoryIds, productIds)',
  })
  findApplicable(
    @Param('storeId') storeId: string,
    @Query() query: ApplicableDiscountQueryDto,
  ) {
    return this.discountsService.findApplicable(storeId, query);
  }

  @Put(':id')
  @Permissions('discounts.write')
  @ApiOperation({ summary: 'Update discount' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateDiscountDto,
  ) {
    return this.discountsService.update(storeId, id, dto);
  }

  @Delete(':id')
  @Permissions('discounts.write')
  @ApiOperation({ summary: 'Soft delete discount (sets active=false)' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.discountsService.remove(storeId, id);
  }
}
