import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report-query.dto';

@ApiTags('Reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)
@Controller('stores/:storeId/reports')
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get('sales')
  @ApiOperation({
    summary: 'Sales report: aggregated by date, top 5 products by revenue',
  })
  getSalesReport(
    @Param('storeId') storeId: string,
    @Query() query: ReportQueryDto,
  ) {
    return this.reportsService.getSalesReport(storeId, query);
  }

  @Get('profit')
  @RequiresFeature('hasReportsAll')
  @ApiOperation({
    summary: 'Profit report: income, expenses, profit, margin %',
  })
  getProfitReport(
    @Param('storeId') storeId: string,
    @Query() query: ReportQueryDto,
  ) {
    return this.reportsService.getProfitReport(storeId, query);
  }

  @Get('products')
  @RequiresFeature('hasReportsAll')
  @ApiOperation({
    summary:
      'Products report: top sellers by qty/revenue, dead stock, total stock value',
  })
  getProductsReport(
    @Param('storeId') storeId: string,
    @Query() query: ReportQueryDto,
  ) {
    return this.reportsService.getProductsReport(storeId, query);
  }

  @Get('staff')
  @RequiresFeature('hasReportsAll')
  @ApiOperation({
    summary: 'Staff report: sales per cashier, avg check per cashier',
  })
  getStaffReport(
    @Param('storeId') storeId: string,
    @Query() query: ReportQueryDto,
  ) {
    return this.reportsService.getStaffReport(storeId, query);
  }
}
