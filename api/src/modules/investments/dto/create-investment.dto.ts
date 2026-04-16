import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNumber, IsOptional, IsEnum, IsDateString, MaxLength } from 'class-validator';
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
  amount: number;

  @ApiPropertyOptional({ example: 60000 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  returnAmount?: number;

  @ApiProperty({ example: 'Иванов Иван' })
  @IsString()
  investorName: string;

  @ApiPropertyOptional({ example: '+992901234567' })
  @IsOptional()
  @IsString()
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
}
