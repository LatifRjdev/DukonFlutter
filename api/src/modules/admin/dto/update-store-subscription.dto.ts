import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsNotEmpty } from 'class-validator';

const PLANS = ['START', 'BUSINESS', 'PREMIUM'];
const STATUSES = ['TRIAL', 'ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED'];

export class UpdateStoreSubscriptionDto {
  @ApiProperty({ enum: PLANS })
  @IsNotEmpty()
  @IsEnum(PLANS)
  plan: string;

  // status and currentPeriodEnd are REQUIRED, not optional. The server-side
  // entitlement guards consult both, so a plan set on an EXPIRED or lapsed
  // subscription grants nothing — the admin would see the new plan and no
  // change in behaviour. Requiring all three makes the grant take effect.
  @ApiProperty({ enum: STATUSES })
  @IsNotEmpty()
  @IsEnum(STATUSES)
  status: string;

  @ApiProperty({ example: '2027-01-01T00:00:00.000Z' })
  @IsNotEmpty()
  @IsDateString()
  currentPeriodEnd: string;
}
