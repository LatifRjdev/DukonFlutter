import { IsDateString } from 'class-validator';

export class LoyaltyAnalyticsQueryDto {
  @IsDateString()
  from: string;

  @IsDateString()
  to: string;
}
