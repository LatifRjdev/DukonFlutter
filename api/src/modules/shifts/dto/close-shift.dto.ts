import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, Min } from 'class-validator';

export class CloseShiftDto {
  @ApiProperty({ description: 'Actual closing cash amount in the drawer' })
  @IsNumber()
  @Min(0)
  closingCash: number;
}
