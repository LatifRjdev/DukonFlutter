import {
  Controller,
  Post,
  Get,
  Param,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ImpersonationService } from './impersonation.service';

// AuditInterceptor is applied here (matching every other mutating
// Admin*Controller in this codebase — see AdminBannersController etc.) so
// that an admin *requesting* or *ending* impersonation access is itself
// permanently logged, independent of whatever viaImpersonation tagging
// happens later on routes actually hit with the resulting token.
@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin')
export class ImpersonationAdminController {
  constructor(private readonly impersonationService: ImpersonationService) {}

  @Post('users/:id/impersonate')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @ApiOperation({
    summary:
      'Request impersonation access to a user account (requires their in-app approval)',
  })
  request(
    @Param('id') targetUserId: string,
    @CurrentUser('id') adminId: string,
  ) {
    return this.impersonationService.request(adminId, targetUserId);
  }

  @Get('impersonation/:id/token')
  @ApiOperation({
    summary: 'Fetch the impersonation token once the request has been approved',
  })
  getToken(@Param('id') id: string) {
    return this.impersonationService
      .issueToken(id)
      .then((token) => ({ token }));
  }

  @Post('impersonation/:id/end')
  @ApiOperation({ summary: 'End an active impersonation session immediately' })
  end(@Param('id') id: string) {
    return this.impersonationService.end(id);
  }
}
