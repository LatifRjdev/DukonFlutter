import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { SalesService } from './sales.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { SaleQueryDto } from './dto/sale-query.dto';
import { RefundSaleDto } from './dto/refund-sale.dto';

@ApiTags('Sales')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/sales')
export class SalesController {
  constructor(private salesService: SalesService) {}

  @Post()
  @Permissions('sales.manage')
  @ApiOperation({ summary: 'Create a sale' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateSaleDto) {
    return this.salesService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List sales with filters' })
  findAll(@Param('storeId') storeId: string, @Query() query: SaleQueryDto) {
    return this.salesService.findAll(storeId, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get sale details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.salesService.findOne(storeId, id);
  }

  @Post(':id/refund')
  @Permissions('sales.refund')
  @ApiOperation({ summary: 'Refund a sale (full or partial)' })
  refund(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: RefundSaleDto,
  ) {
    return this.salesService.refund(storeId, id, dto);
  }
}
