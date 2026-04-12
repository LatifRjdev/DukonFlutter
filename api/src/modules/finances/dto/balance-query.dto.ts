import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum } from 'class-validator';

export enum BalancePeriod {
  WEEK = 'week',
  MONTH = 'month',
  YEAR = 'year',
}

export class BalanceQueryDto {
  @ApiPropertyOptional({
    enum: BalancePeriod,
    default: BalancePeriod.MONTH,
    description: 'Period for balance calculation',
  })
  @IsOptional()
  @IsEnum(BalancePeriod)
  period?: BalancePeriod;
}
