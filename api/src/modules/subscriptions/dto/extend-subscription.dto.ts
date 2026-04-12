import { IsInt, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ExtendSubscriptionDto {
  @ApiProperty({ description: 'Number of days to extend' })
  @IsInt()
  @Min(1)
  days: number;
}
