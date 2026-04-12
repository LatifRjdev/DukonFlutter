import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class RateHistoryQueryDto {
  @ApiPropertyOptional({
    example: 'USD',
    description: 'Currency code: USD, RUB, EUR, CNY',
  })
  @IsOptional()
  @IsString()
  currency?: string;

  @ApiPropertyOptional({
    example: 30,
    description: 'Number of days of history (1-365)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  days?: number;
}
