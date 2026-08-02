import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ImpersonationService } from './impersonation.service';
import { ImpersonationAdminController } from './impersonation-admin.controller';
import { ImpersonationController } from './impersonation.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';

// JwtModule is registered empty here — same pattern as AuthModule.
// ImpersonationService always passes `secret: JWT_ACCESS_SECRET` (read via
// ConfigService) explicitly on every jwt.sign() call, and an explicit
// per-call `secret` option always wins over whatever (if anything)
// JwtModule itself was configured with, so this stays correctly aligned
// with JwtAccessStrategy's verification secret without needing a second,
// differently-configured global JwtModule.
@Module({
  imports: [NotificationsModule, JwtModule.register({})],
  controllers: [ImpersonationAdminController, ImpersonationController],
  providers: [ImpersonationService, AuditInterceptor],
})
export class ImpersonationModule {}
