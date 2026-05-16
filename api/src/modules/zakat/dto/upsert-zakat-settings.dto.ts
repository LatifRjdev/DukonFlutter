import {
  IsOptional,
  IsNumber,
  IsBoolean,
  IsDateString,
  IsEnum,
  Min,
  Max,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { Currency } from '@prisma/client';

export class UpsertZakatSettingsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  nisabGold?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  nisabSilver?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  nisabAmount?: number;

  @ApiPropertyOptional({ enum: Currency })
  @IsOptional()
  @IsEnum(Currency)
  nisabCurrency?: Currency;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  haulStartDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  zakatRate?: number;

  @ApiPropertyOptional({ description: 'Cash on hand (TJS) included in total assets when includeCash=true' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  cashOnHand?: number;

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
