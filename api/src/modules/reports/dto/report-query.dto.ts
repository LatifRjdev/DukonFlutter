import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString } from 'class-validator';

export class ReportQueryDto {
  @ApiPropertyOptional({
    description: 'Start date (ISO string)',
    example: '2026-01-01',
  })
  @IsOptional()
  @IsString()
  from?: string;

  @ApiPropertyOptional({
    description: 'End date (ISO string)',
    example: '2026-01-31',
  })
  @IsOptional()
  @IsString()
  to?: string;

  @ApiPropertyOptional({ enum: ['IN_STORE', 'ONLINE'] })
  @IsOptional()
  @IsIn(['IN_STORE', 'ONLINE'])
  channel?: 'IN_STORE' | 'ONLINE';
}
