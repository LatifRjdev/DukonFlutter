import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsString, IsNumber, IsOptional, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class CountItemUpdateDto {
  @ApiProperty({ description: 'Product ID' })
  @IsString()
  productId: string;

  @ApiProperty({ description: 'Actual quantity counted', minimum: 0 })
  @IsNumber({ maxDecimalPlaces: 3 })
  @Min(0)
  actualQty: number;
}

export class UpdateCountItemsDto {
  @ApiProperty({ type: [CountItemUpdateDto], description: 'Array of product count updates' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CountItemUpdateDto)
  items: CountItemUpdateDto[];
}
