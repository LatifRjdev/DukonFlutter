import { IsNumber, IsOptional, IsString, IsObject, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateZakatPaymentDto {
  @ApiProperty()
  @IsNumber()
  @Min(0)
  amount: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  totalAssets?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  zakatDue?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsObject()
  breakdown?: Record<string, any>;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  // Z-P1-1: client-generated UUID. When present, the backend
  // upserts on (storeId, localId) so a retried POST after a flaky
  // network is a no-op rather than a duplicate row. Optional for
  // backwards compatibility with older Flutter builds.
  @ApiPropertyOptional({ description: 'Client-generated UUID for idempotency' })
  @IsOptional()
  @IsString()
  localId?: string;
}
