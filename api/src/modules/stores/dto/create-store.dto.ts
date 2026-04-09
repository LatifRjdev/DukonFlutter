import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsString, IsEnum, IsOptional, Matches } from 'class-validator';

export class CreateStoreDto {
  @ApiProperty({ example: 'Мой магазин' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ enum: ['GROCERY', 'CLOTHING', 'ELECTRONICS', 'HARDWARE', 'PHARMACY', 'OTHER'] })
  @IsNotEmpty()
  @IsEnum(['GROCERY', 'CLOTHING', 'ELECTRONICS', 'HARDWARE', 'PHARMACY', 'OTHER'])
  category: string;

  @ApiPropertyOptional({ enum: ['TJS', 'USD', 'RUB'], default: 'TJS' })
  @IsOptional()
  @IsEnum(['TJS', 'USD', 'RUB'])
  currency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^\+?\d{9,15}$/)
  phone?: string;
}
