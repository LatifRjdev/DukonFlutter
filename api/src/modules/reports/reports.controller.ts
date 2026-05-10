import { Controller, Get, Param, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { ReportsService } from './reports.service';
import { ExportService } from './export.service';
import { ReportQueryDto } from './dto/report-query.dto';

@ApiTags('Reports')
@ApiBearerAuth()
// Bug #23/24 (2026-05-10 matrix probe): reports controller had no
// PermissionsGuard, so ANY authenticated staff (including CASHIER and
// WAREHOUSE) could read sales, profit, and products reports — and
// PREMIUM-tier cashiers could even export sales as xlsx. Add the
// guard so per-route @Permissions decorators take effect.
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard, SubscriptionGuard)
@Controller('stores/:storeId/reports')
export class ReportsController {
  constructor(
    private reportsService: ReportsService,
    private exportService: ExportService,
  ) {}

  // /sales originally lacked @RequiresFeature; the other three had it.
  // That left the most-hit report open to START tier. All four now gated.
  @Get('sales')
  @RequiresFeature('hasReportsAll')
  @Permissions('reports.view')
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
  @Permissions('reports.view')
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
  @Permissions('reports.view')
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
  @Permissions('reports.view')
  @ApiOperation({
    summary: 'Staff report: sales per cashier, avg check per cashier',
  })
  getStaffReport(
    @Param('storeId') storeId: string,
    @Query() query: ReportQueryDto,
  ) {
    return this.reportsService.getStaffReport(storeId, query);
  }

  // D.2: PREMIUM-only xlsx export. Closes the dead `hasExport` flag
  // by giving it an actual gated endpoint. Streams the file as a
  // direct download — no separate "prepare → fetch URL" round-trip
  // needed for the data sizes we cap at (10k rows).
  @Get('export')
  @RequiresFeature('hasExport')
  @Permissions('reports.view')
  @ApiOperation({
    summary:
      'Export sales / products / customers as xlsx. Query: ?type=sales|products|customers',
  })
  async exportXlsx(
    @Param('storeId') storeId: string,
    @Query('type') type: string,
    @Res() res: Response,
  ) {
    const t = this.exportService.validateType(type);
    let buf: Buffer;
    if (t === 'sales') buf = await this.exportService.exportSales(storeId);
    else if (t === 'products')
      buf = await this.exportService.exportProducts(storeId);
    else buf = await this.exportService.exportCustomers(storeId);

    res.set({
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${this.exportService.filenameFor(
        t,
      )}"`,
      'Content-Length': buf.length.toString(),
    });
    res.send(buf);
  }
}
