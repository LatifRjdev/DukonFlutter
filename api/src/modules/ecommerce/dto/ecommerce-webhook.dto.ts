import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsString,
  IsOptional,
  IsNumber,
  IsArray,
  ArrayMinSize,
  ValidateNested,
  ValidateIf,
  IsDefined,
  Matches,
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

  // Same convention as CreateCustomerDto (create-customer.dto.ts): keeps
  // Telegram-receipt lookup, debt-by-phone search, and SMS working, and
  // ensures createOrder()'s Customer upsert on [storeId, phone] dedupes
  // against the same customer's in-store purchases rather than creating
  // a second record for an unnormalized phone from the merchant's site.
  @ApiProperty({ example: '+992909000000' })
  @IsString()
  @Matches(/^\+992\d{9}$/, {
    message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)',
  })
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
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => EcommerceOrderItemDto)
  items?: EcommerceOrderItemDto[];

  @ApiPropertyOptional()
  @ValidateIf((o) => o.event === 'order.created')
  // ValidateNested alone is a no-op when the property is missing
  // entirely — it only validates an object that's actually present.
  // Without IsDefined, an order.created payload that simply omits
  // `customer` passes validation with zero errors and then crashes with
  // a raw TypeError on `dto.customer!.phone` inside the transaction
  // (ecommerce-orders.service.ts) instead of getting the same clean 422
  // + owner-notification every other rejection path in this flow
  // produces.
  @IsDefined()
  @ValidateNested()
  @Type(() => EcommerceCustomerDto)
  customer?: EcommerceCustomerDto;

  @ApiPropertyOptional()
  @ValidateIf((o) => o.event === 'order.created')
  @IsNumber()
  @Min(0)
  totalAmount?: number;
}
