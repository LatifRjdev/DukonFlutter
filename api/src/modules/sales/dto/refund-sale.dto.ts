import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsNumber, IsOptional, IsString, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class RefundItemDto {
  @ApiProperty()
  @IsString()
  saleItemId: string;

  @ApiProperty()
  @IsNumber()
  @Min(1)
  quantity: number;
}

export class RefundSaleDto {
  @ApiProperty({ type: [RefundItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RefundItemDto)
  items: RefundItemDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  reason?: string;
}
