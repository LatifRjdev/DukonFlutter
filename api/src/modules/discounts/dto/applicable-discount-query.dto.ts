import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsString, Min } from 'class-validator';
import { Type, Transform } from 'class-transformer';

export class ApplicableDiscountQueryDto {
  @ApiPropertyOptional({ description: 'Cart total amount' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  total?: number;

  @ApiPropertyOptional({
    description: 'Comma-separated category IDs in the cart',
  })
  @IsOptional()
  @IsString()
  categoryIds?: string;

  @ApiPropertyOptional({
    description: 'Comma-separated product IDs in the cart',
  })
  @IsOptional()
  @IsString()
  productIds?: string;
}
