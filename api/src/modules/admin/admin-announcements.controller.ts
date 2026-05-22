import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  UseInterceptors,
  Request,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { AnnouncementsQueryDto } from './dto/announcements-query.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/announcements')
export class AdminAnnouncementsController {
  constructor(private readonly adminService: AdminService) {}

  @Post()
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({
    summary: 'Send announcement push notification to filtered users',
  })
  createAnnouncement(@Body() dto: CreateAnnouncementDto, @Request() req: any) {
    return this.adminService.createAnnouncement(dto, req.user.id);
  }

  @Post('preview')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({
    summary: 'Preview an announcement — returns rendered text + audience count',
  })
  previewAnnouncement(@Body() dto: CreateAnnouncementDto) {
    return this.adminService.previewAnnouncement(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List all past announcements' })
  listAnnouncements(@Query() query: AnnouncementsQueryDto) {
    return this.adminService.listAnnouncements(query);
  }
}
