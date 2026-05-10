import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsBoolean, IsInt, Min, IsNumber } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdatePlanDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  price?: number;

  // maxStores dropped in 2026-05 (Sprint D.1) — see PlanLimitField.

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  maxProducts?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  maxStaff?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxDiscounts?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasReportsAll?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasExport?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasTelegram?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasAllPush?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasDelivery?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasInventory?: boolean;
}
