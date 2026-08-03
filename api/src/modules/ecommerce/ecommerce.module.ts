import { Module } from '@nestjs/common';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { EcommerceIntegrationController } from './ecommerce-integration.controller';
import { EcommerceOrdersService } from './ecommerce-orders.service';
import { EcommerceOrdersController } from './ecommerce-orders.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [EcommerceIntegrationController, EcommerceOrdersController],
  providers: [
    EcommerceOutboundService,
    EcommerceIntegrationService,
    EcommerceOrdersService,
  ],
  exports: [EcommerceOutboundService],
})
export class EcommerceModule {}
