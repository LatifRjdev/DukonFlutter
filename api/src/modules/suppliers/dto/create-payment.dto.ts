import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, Min, IsEnum, IsOptional, IsString } from 'class-validator';
import { SalePaymentType } from '@prisma/client';

export class CreateSupplierPaymentDto {
  @ApiProperty({ description: 'Payment amount', minimum: 0.01 })
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiProperty({ enum: SalePaymentType, description: 'Payment method' })
  @IsEnum(SalePaymentType)
  method: SalePaymentType;

  @ApiPropertyOptional({ description: 'Optional notes' })
  @IsOptional()
  @IsString()
  notes?: string;

  // E.3: client-supplied UUID for offline-replay idempotency. Server
  // returns the existing payment row instead of double-decrementing
  // the supplier debt if it sees the same localId again.
  @ApiPropertyOptional({
    description: 'Client-generated UUID for idempotent replay',
  })
  @IsOptional()
  @IsString()
  localId?: string;
}
