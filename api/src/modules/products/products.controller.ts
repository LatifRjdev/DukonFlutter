import {
  Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ProductsService } from './products.service';
import { StockMovementsService } from './stock-movements.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductQueryDto } from './dto/product-query.dto';
import { CreateStockMovementDto } from './dto/create-stock-movement.dto';

@ApiTags('Products')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/products')
export class ProductsController {
  constructor(
    private productsService: ProductsService,
    private stockMovementsService: StockMovementsService,
  ) {}

  @Post()
  @Permissions('products.manage')
  @ApiOperation({ summary: 'Create product' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateProductDto) {
    return this.productsService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List products' })
  findAll(@Param('storeId') storeId: string, @Query() query: ProductQueryDto) {
    return this.productsService.findAll(storeId, query);
  }

  @Get('barcode/:barcode')
  @ApiOperation({ summary: 'Find product by barcode' })
  findByBarcode(@Param('storeId') storeId: string, @Param('barcode') barcode: string) {
    return this.productsService.findByBarcode(storeId, barcode);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get product details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.productsService.findOne(storeId, id);
  }

  @Put(':id')
  @Permissions('products.manage')
  @ApiOperation({ summary: 'Update product' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
  ) {
    return this.productsService.update(storeId, id, dto);
  }

  @Delete(':id')
  @Permissions('products.delete')
  @ApiOperation({ summary: 'Deactivate product' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.productsService.remove(storeId, id);
  }

  @Post(':productId/stock-movements')
  @Permissions('stock.manage')
  @ApiOperation({ summary: 'Create stock movement' })
  createStockMovement(
    @Param('storeId') storeId: string,
    @Body() dto: CreateStockMovementDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.stockMovementsService.create(storeId, dto, userId);
  }

  @Get(':productId/stock-movements')
  @ApiOperation({ summary: 'Get stock movements for product' })
  getStockMovements(
    @Param('storeId') storeId: string,
    @Param('productId') productId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.stockMovementsService.findAll(storeId, productId, page, limit);
  }
}
