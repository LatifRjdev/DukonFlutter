import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional } from 'class-validator';

export class CreateDeliveryDto {
  @ApiProperty({ description: 'Sale ID this delivery is for' })
  @IsString()
  saleId: string;

  @ApiProperty({ description: 'Delivery address' })
  @IsString()
  address: string;

  @ApiPropertyOptional({ description: 'Staff ID of the courier' })
  @IsOptional()
  @IsString()
  courierId?: string;

  @ApiPropertyOptional({ description: 'Additional notes' })
  @IsOptional()
  @IsString()
  notes?: string;
}
