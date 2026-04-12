import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { FinancesService } from './finances.service';
import { FinanceQueryDto } from './dto/finance-query.dto';
import { BalanceQueryDto } from './dto/balance-query.dto';

@ApiTags('Finances')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/finances')
export class FinancesController {
  constructor(private financesService: FinancesService) {}

  @Get('overview')
  @ApiOperation({
    summary: 'Get home dashboard overview (today stats + product counts)',
  })
  getOverview(@Param('storeId') storeId: string) {
    return this.financesService.getOverview(storeId);
  }

  @Get('dashboard')
  @ApiOperation({ summary: 'Get financial dashboard data' })
  getDashboard(
    @Param('storeId') storeId: string,
    @Query() query: FinanceQueryDto,
  ) {
    return this.financesService.getDashboard(storeId, query);
  }

  @Get('summary')
  @ApiOperation({ summary: 'Get financial summary for period' })
  getSummary(
    @Param('storeId') storeId: string,
    @Query() query: FinanceQueryDto,
  ) {
    return this.financesService.getSummary(storeId, query);
  }

  @Get('balance')
  @ApiOperation({
    summary:
      'Current balance, income, expenses, profit, daily chart data, recent transactions',
  })
  getBalance(
    @Param('storeId') storeId: string,
    @Query() query: BalanceQueryDto,
  ) {
    return this.financesService.getBalance(storeId, query);
  }

  @Get('credits-summary')
  @ApiOperation({
    summary:
      'Receivables (customers with debts) and payables (suppliers with debts), aggregated',
  })
  getCreditsSummary(@Param('storeId') storeId: string) {
    return this.financesService.getCreditsSummary(storeId);
  }
}
