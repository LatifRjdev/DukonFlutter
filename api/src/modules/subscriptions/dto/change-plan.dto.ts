import { IsEnum, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { SubscriptionPlanEnum } from './request-change.dto';

export class ChangePlanDto {
  @ApiProperty({ enum: SubscriptionPlanEnum })
  @IsEnum(SubscriptionPlanEnum)
  @IsNotEmpty()
  plan: SubscriptionPlanEnum;
}
