import { Controller, Get, Post, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { CurrenciesService } from './currencies.service';
import { RateHistoryQueryDto } from './dto/rate-history-query.dto';

@ApiTags('Currencies')
@Controller('currencies')
export class CurrenciesController {
  constructor(private currenciesService: CurrenciesService) {}

  @Get('rates')
  @ApiOperation({
    summary: 'Get latest NBT exchange rates (USD, RUB, EUR, CNY)',
  })
  getLatestRates() {
    return this.currenciesService.getLatestRates();
  }

  @Post('rates/fetch')
  @ApiOperation({
    summary: 'Manually trigger rate fetch from NBT',
  })
  async fetchRates(): Promise<any[]> {
    return this.currenciesService.fetchRatesFromNbt();
  }

  @Get('rates/history')
  @ApiOperation({
    summary: 'Get rate history for a currency (default: USD, 30 days)',
  })
  getRateHistory(@Query() query: RateHistoryQueryDto) {
    return this.currenciesService.getRateHistory(
      query.currency ?? 'USD',
      query.days ?? 30,
    );
  }
}
