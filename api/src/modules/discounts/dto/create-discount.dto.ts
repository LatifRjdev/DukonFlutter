import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsNumber,
  IsEnum,
  IsBoolean,
  IsDateString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export enum DiscountType {
  FIXED = 'FIXED',
  PERCENTAGE = 'PERCENTAGE',
}

export enum DiscountCondition {
  CART = 'CART',
  CATEGORY = 'CATEGORY',
  PRODUCT = 'PRODUCT',
}

export class CreateDiscountDto {
  @ApiProperty()
  @IsString()
  name: string;

  @ApiProperty({ enum: DiscountType })
  @IsEnum(DiscountType)
  type: DiscountType;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  value: number;

  @ApiProperty({ enum: DiscountCondition })
  @IsEnum(DiscountCondition)
  condition: DiscountCondition;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  categoryId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  productId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  minTotal?: number;

  @ApiProperty()
  @IsDateString()
  startDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
