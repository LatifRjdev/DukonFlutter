import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminStoresController } from './admin-stores.controller';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminPlansController } from './admin-plans.controller';
import { AdminAnnouncementsController } from './admin-announcements.controller';
import { AdminBannersController } from './admin-banners.controller';
import { AdminNotificationsController } from './admin-notifications.controller';
import { AdminAuditLogController } from './admin-audit-log.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { StoresModule } from '../stores/stores.module';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminExportService } from './admin-export.service';

@Module({
  imports: [NotificationsModule, StoresModule],
  controllers: [
    AdminUsersController,
    AdminStoresController,
    AdminDashboardController,
    AdminPlansController,
    AdminAnnouncementsController,
    AdminBannersController,
    AdminNotificationsController,
    AdminAuditLogController,
  ],
  providers: [AdminService, AuditInterceptor, AdminExportService],
  exports: [AdminService, AdminExportService],
})
export class AdminModule {}
