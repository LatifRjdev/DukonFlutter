import { Module } from '@nestjs/common';
import { SalesController } from './sales.controller';
import { SalesService } from './sales.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { EcommerceModule } from '../ecommerce/ecommerce.module';

@Module({
  imports: [NotificationsModule, LoyaltyModule, EcommerceModule],
  controllers: [SalesController],
  providers: [SalesService],
  exports: [SalesService],
})
export class SalesModule {}
