import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

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
}
