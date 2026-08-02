import { Controller, Put, Param, Body, UseGuards } from '@nestjs/common';
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
}
