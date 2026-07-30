import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsNumber,
  Min,
  Max,
  IsInt,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { PaymentMethod } from '@prisma/client';

// Sanity guard, not a real business limit: the most expensive plan
// (PREMIUM) is 600 TJS/period (see SubscriptionPlanConfig seed in
// subscriptions.service.ts). This ceiling is set well above what any
// legitimate bulk/multi-period manual payment would need, purely to
// catch a fat-fingered extra digit before it becomes a permanent,
// already-APPROVED Payment row (unlike requestChange, this amount is
// admin-typed, not server-computed from the plan price).
const MAX_MANUAL_PAYMENT_AMOUNT = 50_000;

export class AdminManualPaymentDto {
  @ApiProperty({ example: 400 })
  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  @Max(MAX_MANUAL_PAYMENT_AMOUNT)
  amount: number;

  @ApiProperty({ enum: PaymentMethod })
  @IsNotEmpty()
  @IsEnum(PaymentMethod)
  method: PaymentMethod;

  @ApiProperty({
    example: 30,
    description: 'Number of days to extend the subscription by',
  })
  @IsNotEmpty()
  @IsInt()
  @Min(1)
  periodDays: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
