import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, Min } from 'class-validator';

export class OpenShiftDto {
  @ApiProperty({ description: 'Opening cash amount in the drawer' })
  @IsNumber()
  @Min(0)
  openingCash: number;
}
