import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { StockMovementsService } from './stock-movements.service';
import { ImportProductsService } from './import-products.service';
import { StockAlertsService } from './stock-alerts.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { EcommerceModule } from '../ecommerce/ecommerce.module';

@Module({
  imports: [NotificationsModule, EcommerceModule],
  controllers: [ProductsController],
  providers: [
    ProductsService,
    StockMovementsService,
    ImportProductsService,
    StockAlertsService,
  ],
  exports: [ProductsService, StockMovementsService],
})
export class ProductsModule {}
