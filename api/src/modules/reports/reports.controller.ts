import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report-query.dto';

@ApiTags('Reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
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
