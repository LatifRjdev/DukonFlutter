import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Query,
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
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';
import { CreateUserByAdminDto } from './dto/create-user-by-admin.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/users')
export class AdminUsersController {
  constructor(private readonly adminService: AdminService) {}

  @Get()
  @ApiOperation({ summary: 'List all users with pagination and filters' })
  listUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminService.listUsers(query);
  }

  @Post()
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @ApiOperation({ summary: 'Manually create a user account (optionally with a first store)' })
  createUser(@Body() dto: CreateUserByAdminDto) {
    return this.adminService.createUserManually(dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user detail with stores and subscriptions' })
  getUserDetail(@Param('id') id: string) {
    return this.adminService.getUserDetail(id);
  }

  @Get(':id/stores')
  @ApiOperation({ summary: 'List stores owned by a user' })
  listUserStores(@Param('id') id: string) {
    return this.adminService.listUserStores(id);
  }

  @Put(':id/toggle-admin')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Toggle admin flag for a user' })
  toggleAdmin(@Param('id') id: string) {
    return this.adminService.toggleAdmin(id);
  }

  @Put(':id/block')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Block user and revoke all refresh tokens' })
  blockUser(@Param('id') id: string) {
    return this.adminService.blockUser(id);
  }

  @Put(':id/unblock')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Unblock a previously blocked user' })
  unblockUser(@Param('id') id: string) {
    return this.adminService.unblockUser(id);
  }

  @Delete(':id')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Soft-delete user: anonymize phone, nullify email' })
  deleteUser(@Param('id') id: string) {
    return this.adminService.deleteUser(id);
  }
}
