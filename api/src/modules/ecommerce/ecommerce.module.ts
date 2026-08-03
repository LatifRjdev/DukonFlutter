import { Module } from '@nestjs/common';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  providers: [EcommerceOutboundService],
  exports: [EcommerceOutboundService],
})
export class EcommerceModule {}
