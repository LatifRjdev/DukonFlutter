import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsOptional,
  IsEnum,
  IsDateString,
  MaxLength,
  Min,
  Max,
  Matches,
} from 'class-validator';
import { InvestmentStatus } from '@prisma/client';

export class CreateInvestmentDto {
  @ApiProperty({ example: 'Закупка оборудования' })
  @IsString()
  @MaxLength(255)
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: 50000 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(9_999_999_999.99)
  amount: number;

  @ApiPropertyOptional({ example: 60000 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(9_999_999_999.99)
  returnAmount?: number;

  @ApiProperty({ example: 'Иванов Иван' })
  @IsString()
  investorName: string;

  @ApiPropertyOptional({ example: '+992901234567' })
  @IsOptional()
  @IsString()
  @Matches(/^\+992\d{9}$/, {
    message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)',
  })
  investorPhone?: string;

  @ApiPropertyOptional({ enum: InvestmentStatus, default: 'ACTIVE' })
  @IsOptional()
  @IsEnum(InvestmentStatus)
  status?: InvestmentStatus;

  @ApiProperty({ example: '2026-04-16T00:00:00.000Z' })
  @IsDateString()
  startDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiPropertyOptional({ description: 'Client-generated UUID for idempotent replay' })
  @IsOptional()
  @IsString()
  localId?: string;
}
