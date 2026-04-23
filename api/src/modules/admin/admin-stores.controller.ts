import {
  Controller,
  Get,
  Put,
  Param,
  Query,
  Body,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { AdminStoresQueryDto } from './dto/admin-stores-query.dto';
import { TransferStoreDto } from './dto/transfer-store.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/stores')
export class AdminStoresController {
  constructor(private readonly adminService: AdminService) {}

  @Get()
  @ApiOperation({ summary: 'List all stores with pagination and filters' })
  listStores(@Query() query: AdminStoresQueryDto) {
    return this.adminService.listStores(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get store detail with stats' })
  getStoreDetail(@Param('id') id: string) {
    return this.adminService.getStoreDetail(id);
  }

  @Get(':id/subscription')
  @ApiOperation({ summary: 'Get subscription for a store with recent payments' })
  getStoreSubscription(@Param('id') id: string) {
    return this.adminService.getStoreSubscription(id);
  }

  @Put(':id/suspend')
  @ApiOperation({ summary: 'Suspend a store' })
  suspendStore(@Param('id') id: string) {
    return this.adminService.suspendStore(id);
  }

  @Put(':id/unsuspend')
  @ApiOperation({ summary: 'Unsuspend a store' })
  unsuspendStore(@Param('id') id: string) {
    return this.adminService.unsuspendStore(id);
  }

  @Put(':id/transfer')
  @ApiOperation({ summary: 'Transfer store ownership to another user' })
  transferStore(@Param('id') id: string, @Body() dto: TransferStoreDto) {
    return this.adminService.transferStore(id, dto);
  }
}
