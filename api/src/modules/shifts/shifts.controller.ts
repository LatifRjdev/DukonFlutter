import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ShiftsService } from './shifts.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto } from './dto/close-shift.dto';

@ApiTags('shifts')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/shifts')
export class ShiftsController {
  constructor(private shiftsService: ShiftsService) {}

  @Post('open')
  @ApiOperation({ summary: 'Open a new shift' })
  open(
    @Param('storeId') storeId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: OpenShiftDto,
  ) {
    return this.shiftsService.openShift(storeId, userId, dto);
  }

  @Post(':id/close')
  @ApiOperation({ summary: 'Close an active shift' })
  close(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CloseShiftDto,
  ) {
    return this.shiftsService.closeShift(storeId, id, userId, dto);
  }

  @Get('current')
  @ApiOperation({ summary: 'Get current active shift for logged-in user' })
  getCurrent(
    @Param('storeId') storeId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.shiftsService.findCurrent(storeId, userId);
  }

  @Get()
  @ApiOperation({ summary: 'List shift history with pagination and filters' })
  findAll(
    @Param('storeId') storeId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('staffId') staffId?: string,
    @Query('dateFrom') dateFrom?: string,
    @Query('dateTo') dateTo?: string,
  ) {
    return this.shiftsService.findAll(
      storeId,
      page || 1,
      limit || 20,
      staffId,
      dateFrom,
      dateTo,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get shift detail' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.shiftsService.findOne(storeId, id);
  }

  @Get(':id/z-report')
  @ApiOperation({ summary: 'Get full Z-report for a shift' })
  getZReport(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.shiftsService.getZReport(storeId, id);
  }
}
