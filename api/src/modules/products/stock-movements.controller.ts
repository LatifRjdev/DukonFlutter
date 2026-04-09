import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { StockMovementsService } from './stock-movements.service';
import { CreateStockMovementDto } from './dto/create-stock-movement.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('stock-movements')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/stock-movements')
export class StockMovementsController {
  constructor(private readonly stockMovementsService: StockMovementsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a stock movement (product incoming)' })
  async create(
    @Param('storeId') storeId: string,
    @Body() dto: CreateStockMovementDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.stockMovementsService.create(storeId, dto, userId);
  }

  @Get()
  @ApiOperation({ summary: 'List stock movements' })
  async findAll(
    @Param('storeId') storeId: string,
    @Query('productId') productId?: string,
  ) {
    return this.stockMovementsService.findAll(storeId, productId);
  }
}
