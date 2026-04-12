import { IsNumber, Min, Max } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SetDiscountDto {
  @ApiProperty({ description: 'Discount percentage (0-100, 0 removes discount)' })
  @IsNumber()
  @Min(0)
  @Max(100)
  percent: number;
}
