import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ImpersonationService } from './impersonation.service';
import { RespondImpersonationDto } from './dto/respond-impersonation.dto';

@ApiTags('Impersonation')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('impersonation-requests')
export class ImpersonationController {
  constructor(private readonly impersonationService: ImpersonationService) {}

  @Get('pending')
  @ApiOperation({
    summary:
      "Get the current user's pending impersonation request, if any (used by the mobile consent screen, since the notification itself carries no request id)",
  })
  findPending(@CurrentUser('id') userId: string) {
    return this.impersonationService.findPendingForUser(userId);
  }

  @Put(':id/respond')
  @ApiOperation({
    summary:
      'Approve or reject a pending impersonation request targeting the current user',
  })
  respond(
    @Param('id') id: string,
    @Body() dto: RespondImpersonationDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.impersonationService.respond(id, userId, dto.decision);
  }

  // Target-facing counterpart to POST /admin/impersonation/:id/end.
  // Deliberately NOT under /admin — this is called by whoever is
  // currently holding the impersonation-flavored access token (the
  // target customer's own session banner), and that token's `sub` is an
  // ordinary customer, not an admin, so AdminGuard would always reject
  // it. Guarded only by JwtAuthGuard; ImpersonationService.endSelf()
  // verifies the caller both IS the target user and is presenting a
  // token that actually carries this specific request's id.
  @Post(':id/end')
  @ApiOperation({
    summary:
      "End the current user's own active impersonation (support) session",
  })
  endSelf(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('impersonationRequestId')
    tokenImpersonationRequestId: string | undefined,
  ) {
    return this.impersonationService.endSelf(
      id,
      userId,
      tokenImpersonationRequestId,
    );
  }
}
