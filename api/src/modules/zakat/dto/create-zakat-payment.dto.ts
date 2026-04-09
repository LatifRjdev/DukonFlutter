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
  totalAssets?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  zakatDue?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsObject()
  breakdown?: Record<string, any>;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}
