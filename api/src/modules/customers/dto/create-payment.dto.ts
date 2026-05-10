import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsUUID, IsNumber, Min, IsEnum, IsOptional, IsString } from 'class-validator';
import { SalePaymentType } from '@prisma/client';

export class CreateCustomerPaymentDto {
  @ApiProperty({ description: 'Sale ID to pay debt for' })
  @IsUUID()
  saleId: string;

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
  // the debt if it sees the same localId again.
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  localId?: string;
}
