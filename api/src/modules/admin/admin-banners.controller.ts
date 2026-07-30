import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { CreateBannerDto } from './dto/create-banner.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/banners')
export class AdminBannersController {
  constructor(private readonly adminService: AdminService) {}

  @Post()
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @ApiOperation({ summary: 'Create a new in-app banner' })
  createBanner(@Body() dto: CreateBannerDto) {
    return this.adminService.createBanner(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List all banners' })
  listBanners() {
    return this.adminService.listBanners();
  }

  @Put(':id/active')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Toggle a banner active/inactive' })
  setBannerActive(@Param('id') id: string, @Body('active') active: boolean) {
    return this.adminService.setBannerActive(id, active);
  }
}
