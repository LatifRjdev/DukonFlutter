import { IsOptional, IsNumber, IsBoolean, IsDateString, IsEnum } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpsertZakatSettingsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  nisabGold?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  nisabSilver?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  nisabAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  haulStartDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  zakatRate?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  includeStock?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  includeCash?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  includeDebts?: boolean;
}
