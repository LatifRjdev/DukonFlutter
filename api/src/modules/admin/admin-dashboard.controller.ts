import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AdminService } from './admin.service';
import { RevenueQueryDto } from './dto/revenue-query.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminDashboardController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard')
  @ApiOperation({ summary: 'Admin dashboard aggregate metrics' })
  getDashboard() {
    return this.adminService.getDashboard();
  }

  @Get('revenue')
  @ApiOperation({ summary: 'Revenue grouped by date (week/month/year)' })
  getRevenue(@Query() query: RevenueQueryDto) {
    return this.adminService.getRevenue(query);
  }

  @Get('dashboard/registrations')
  @ApiOperation({ summary: 'User and store registrations over time' })
  getRegistrations(@Query() query: RevenueQueryDto) {
    return this.adminService.getRegistrations(query);
  }
}
