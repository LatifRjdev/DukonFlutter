import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { StockMovementsService } from './stock-movements.service';
import { ImportProductsService } from './import-products.service';
import { StockAlertsService } from './stock-alerts.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
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
