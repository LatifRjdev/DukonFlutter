import {
  Controller,
  Get,
  Put,
  Delete,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';

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
  @ApiOperation({ summary: 'Toggle admin flag for a user' })
  toggleAdmin(@Param('id') id: string) {
    return this.adminService.toggleAdmin(id);
  }

  @Put(':id/block')
  @ApiOperation({ summary: 'Block user and revoke all refresh tokens' })
  blockUser(@Param('id') id: string) {
    return this.adminService.blockUser(id);
  }

  @Put(':id/unblock')
  @ApiOperation({ summary: 'Unblock a previously blocked user' })
  unblockUser(@Param('id') id: string) {
    return this.adminService.unblockUser(id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete user: anonymize phone, nullify email' })
  deleteUser(@Param('id') id: string) {
    return this.adminService.deleteUser(id);
  }
}
