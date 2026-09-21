import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNumber, IsEnum, IsOptional, IsDateString, Min } from 'class-validator';

export enum AdjustmentType {
  BONUS = 'BONUS',
  DEDUCTION = 'DEDUCTION',
}

export class CreateAdjustmentDto {
  @ApiPropertyOptional({ description: 'Omit to apply this adjustment to every staff member on the period' })
  @IsOptional()
  @IsString()
  staffId?: string;

  @ApiProperty({ enum: AdjustmentType })
  @IsEnum(AdjustmentType)
  type: AdjustmentType;

  @ApiProperty({ example: 50000 })
  @IsNumber()
  @Min(0)
  amount: number;

  @ApiProperty()
  @IsString()
  description: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  date?: string;
}
