import { Module } from '@nestjs/common';
import {
  SubscriptionsController,
  SubscriptionPlansController,
  AdminSubscriptionsController,
} from './subscriptions.controller';
import { SubscriptionsService } from './subscriptions.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  imports: [NotificationsModule, AdminModule],
  controllers: [
    SubscriptionPlansController,
    SubscriptionsController,
    AdminSubscriptionsController,
  ],
  providers: [SubscriptionsService],
  exports: [SubscriptionsService],
})
export class SubscriptionsModule {}
