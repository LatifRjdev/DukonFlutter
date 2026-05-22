import {
  Controller,
  Get,
  Put,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { UpdatePlanDto } from './dto/update-plan.dto';
import { SubscriptionPlan } from '@prisma/client';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/plans')
export class AdminPlansController {
  constructor(private readonly adminService: AdminService) {}

  @Get()
  @ApiOperation({ summary: 'List all subscription plan configs' })
  listPlans() {
    return this.adminService.listPlans();
  }

  @Put(':plan')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Partially update a subscription plan config' })
  updatePlan(
    @Param('plan') plan: SubscriptionPlan,
    @Body() dto: UpdatePlanDto,
  ) {
    return this.adminService.updatePlan(plan, dto);
  }
}
