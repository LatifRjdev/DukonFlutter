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

  // F2.4: DTO write-side field is `paymentMethod`. The persisted Payment
  // row exposes the same value as `method` on read — the asymmetry is
  // preserved for backwards compatibility with existing clients that
  // already POST `paymentMethod` and parse `method` from the response.
  // New code should NOT introduce a third name.
  @ApiProperty({ enum: PaymentMethodEnum })
  @IsEnum(PaymentMethodEnum)
  @IsNotEmpty()
  paymentMethod: PaymentMethodEnum;
}
