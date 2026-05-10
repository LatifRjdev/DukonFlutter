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

  @ApiProperty({
    enum: DiscountType,
    description:
      'FIXED = absolute amount off (TJS). PERCENTAGE = percent off the line/cart total.',
    example: 'PERCENTAGE',
  })
  @IsEnum(DiscountType)
  type: DiscountType;

  @ApiProperty({
    description:
      'When type=FIXED, amount in store currency. When type=PERCENTAGE, value 0–100.',
    example: 10,
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  value: number;

  @ApiProperty({
    enum: DiscountCondition,
    description:
      'CART = applies to whole cart. CATEGORY requires categoryId. PRODUCT requires productId.',
    example: 'CART',
  })
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
