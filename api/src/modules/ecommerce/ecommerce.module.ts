import { Module } from '@nestjs/common';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { EcommerceIntegrationController } from './ecommerce-integration.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [EcommerceIntegrationController],
  providers: [EcommerceOutboundService, EcommerceIntegrationService],
  exports: [EcommerceOutboundService],
})
export class EcommerceModule {}
