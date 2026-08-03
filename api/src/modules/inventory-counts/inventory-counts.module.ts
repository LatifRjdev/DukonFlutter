import { Module } from '@nestjs/common';
import { InventoryCountsController } from './inventory-counts.controller';
import { InventoryCountsService } from './inventory-counts.service';
import { EcommerceModule } from '../ecommerce/ecommerce.module';

@Module({
  imports: [EcommerceModule],
  controllers: [InventoryCountsController],
  providers: [InventoryCountsService],
  exports: [InventoryCountsService],
})
export class InventoryCountsModule {}
