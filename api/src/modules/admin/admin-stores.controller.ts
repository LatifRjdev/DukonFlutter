import {
  Controller,
  Get,
  Put,
  Param,
  Query,
  Body,
  Res,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import type { Response } from 'express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { AdminExportService } from './admin-export.service';
import { AdminStoresQueryDto } from './dto/admin-stores-query.dto';
import { TransferStoreDto } from './dto/transfer-store.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/stores')
export class AdminStoresController {
  constructor(
    private readonly adminService: AdminService,
    private readonly exportService: AdminExportService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'List all stores with pagination and filters' })
  listStores(@Query() query: AdminStoresQueryDto) {
    return this.adminService.listStores(query);
  }

  @Get('export')
  @ApiOperation({ summary: 'Export the current filtered store list as .xlsx' })
  async exportStores(
    @Query() query: AdminStoresQueryDto,
    @Res() res: Response,
  ) {
    const buffer = await this.exportService.exportStores(query);
    res.set({
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="dukonpro-stores-${new Date().toISOString().slice(0, 10)}.xlsx"`,
    });
    res.send(buffer);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get store detail with stats' })
  getStoreDetail(@Param('id') id: string) {
    return this.adminService.getStoreDetail(id);
  }

  @Get(':id/subscription')
  @ApiOperation({
    summary: 'Get subscription for a store with recent payments',
  })
  getStoreSubscription(@Param('id') id: string) {
    return this.adminService.getStoreSubscription(id);
  }

  @Put(':id/suspend')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Suspend a store' })
  suspendStore(@Param('id') id: string) {
    return this.adminService.suspendStore(id);
  }

  @Put(':id/unsuspend')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Unsuspend a store' })
  unsuspendStore(@Param('id') id: string) {
    return this.adminService.unsuspendStore(id);
  }

  @Put(':id/transfer')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Transfer store ownership to another user' })
  transferStore(@Param('id') id: string, @Body() dto: TransferStoreDto) {
    return this.adminService.transferStore(id, dto);
  }
}
