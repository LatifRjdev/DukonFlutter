import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { StockMovementsService } from './stock-movements.service';
import { ImportProductsService } from './import-products.service';

@Module({
  controllers: [ProductsController],
  providers: [ProductsService, StockMovementsService, ImportProductsService],
  exports: [ProductsService, StockMovementsService],
})
export class ProductsModule {}
