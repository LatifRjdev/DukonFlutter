import { IsEnum, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum SubscriptionPlanEnum {
  START = 'START',
  BUSINESS = 'BUSINESS',
  PREMIUM = 'PREMIUM',
}

export enum PaymentMethodEnum {
  CARD = 'CARD',
  MOBILE_TRANSFER = 'MOBILE_TRANSFER',
  CASH = 'CASH',
}

export class RequestChangeDto {
  @ApiProperty({ enum: SubscriptionPlanEnum })
  @IsEnum(SubscriptionPlanEnum)
  @IsNotEmpty()
  plan: SubscriptionPlanEnum;

  @ApiProperty({ enum: PaymentMethodEnum })
  @IsEnum(PaymentMethodEnum)
  @IsNotEmpty()
  paymentMethod: PaymentMethodEnum;
}
