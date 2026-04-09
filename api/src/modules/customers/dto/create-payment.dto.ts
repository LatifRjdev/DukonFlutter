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
}
