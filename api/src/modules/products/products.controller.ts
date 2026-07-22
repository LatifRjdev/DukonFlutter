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
  UseInterceptors,
  UploadedFile,
  Res,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import type { Response } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ProductsService } from './products.service';
import { StockMovementsService } from './stock-movements.service';
import { ImportProductsService } from './import-products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductQueryDto } from './dto/product-query.dto';
import { CreateStockMovementDto } from './dto/create-stock-movement.dto';
import { generateImportTemplate } from './templates/product-import-template';

@ApiTags('Products')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/products')
export class ProductsController {
  constructor(
    private productsService: ProductsService,
    private stockMovementsService: StockMovementsService,
    private importService: ImportProductsService,
  ) {}

  @Post()
  @Permissions('products.manage')
  @ApiOperation({ summary: 'Create product' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateProductDto) {
    return this.productsService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List products' })
  findAll(
    @Param('storeId') storeId: string,
    @Query() query: ProductQueryDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.productsService.findAll(storeId, query, userId);
  }

  @Get('import/template')
  @ApiOperation({ summary: 'Download import template' })
  async downloadTemplate(@Res() res: Response) {
    const buffer = await generateImportTemplate();
    res.set({
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition':
        'attachment; filename="dukon-import-template.xlsx"',
    });
    res.send(buffer);
  }

  @Post('import/preview')
  @Permissions('products.manage')
  @UseInterceptors(
    // F-UPLOAD-1: cap at 5MB. Excel of 10k rows is ~2MB so 5MB is
    // plenty of headroom. Without explicit limits the endpoint
    // accepts arbitrary-size payloads → trivial DoS via RAM
    // exhaustion. Mimetype filter blocks obvious wrong types
    // before the parser allocates buffers.
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const ok = [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.ms-excel',
          'text/csv',
        ].includes(file.mimetype);
        cb(ok ? null : new BadRequestException('Unsupported file type'), ok);
      },
    }),
  )
  @ApiOperation({ summary: 'Preview import file' })
  async previewImport(@UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('Файл не загружен');
    return this.importService.preview(file.buffer);
  }

  @Post('import')
  @Permissions('products.manage')
  @UseInterceptors(
    // F-UPLOAD-1: cap at 5MB. Excel of 10k rows is ~2MB so 5MB is
    // plenty of headroom. Without explicit limits the endpoint
    // accepts arbitrary-size payloads → trivial DoS via RAM
    // exhaustion. Mimetype filter blocks obvious wrong types
    // before the parser allocates buffers.
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const ok = [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.ms-excel',
          'text/csv',
        ].includes(file.mimetype);
        cb(ok ? null : new BadRequestException('Unsupported file type'), ok);
      },
    }),
  )
  @ApiOperation({ summary: 'Import products from file' })
  async importProducts(
    @Param('storeId') storeId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Файл не загружен');
    return this.importService.importProducts(storeId, file.buffer);
  }

  @Get('barcode/:barcode')
  @ApiOperation({ summary: 'Find product by barcode' })
  findByBarcode(
    @Param('storeId') storeId: string,
    @Param('barcode') barcode: string,
  ) {
    return this.productsService.findByBarcode(storeId, barcode);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get product details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.productsService.findOne(storeId, id);
  }

  @Get(':id/batch-profitability')
  @UseGuards(SubscriptionGuard)
  @RequiresFeature('hasBatchProfitability')
  @Permissions('products.viewProfitability')
  @ApiOperation({
    summary: 'Get batch (most recent restock) profitability for a product',
  })
  getBatchProfitability(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
  ) {
    return this.productsService.getBatchProfitability(storeId, id);
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
