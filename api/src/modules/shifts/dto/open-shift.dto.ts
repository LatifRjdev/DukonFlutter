import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class OpenShiftDto {
  @ApiProperty({ description: 'Opening cash amount in the drawer' })
  @IsNumber()
  @Min(0)
  openingCash: number;

  // E.1: client-supplied UUID for offline-replay idempotency. Server
  // returns the existing shift if it sees the same localId again.
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  localId?: string;
}
