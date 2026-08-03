import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsString,
  IsOptional,
  IsNumber,
  IsArray,
  ValidateNested,
  ValidateIf,
  Min,
} from 'class-validator';

export class EcommerceOrderItemDto {
  @ApiProperty()
  @IsString()
  externalProductId: string;

  @ApiProperty()
  @IsNumber()
  @Min(1)
  quantity: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;
}

export class EcommerceCustomerDto {
  @ApiProperty()
  @IsString()
  name: string;

  @ApiProperty()
  @IsString()
  phone: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;
}

export class EcommerceWebhookDto {
  @ApiProperty({ enum: ['order.created', 'order.cancelled'] })
  @IsIn(['order.created', 'order.cancelled'])
  event: 'order.created' | 'order.cancelled';

  @ApiProperty()
  @IsString()
  externalOrderId: string;

  @ApiPropertyOptional({ type: [EcommerceOrderItemDto] })
  @ValidateIf((o) => o.event === 'order.created')
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EcommerceOrderItemDto)
  items?: EcommerceOrderItemDto[];

  @ApiPropertyOptional()
  @ValidateIf((o) => o.event === 'order.created')
  @ValidateNested()
  @Type(() => EcommerceCustomerDto)
  customer?: EcommerceCustomerDto;

  @ApiPropertyOptional()
  @ValidateIf((o) => o.event === 'order.created')
  @IsNumber()
  @Min(0)
  totalAmount?: number;
}
