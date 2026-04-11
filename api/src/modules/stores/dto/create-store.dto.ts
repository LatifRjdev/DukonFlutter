import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsString,
  IsEnum,
  IsOptional,
  Matches,
  MaxLength,
} from 'class-validator';
import { IsSafeText } from '../../../common/validators/safe-text.validator';

export class CreateStoreDto {
  @ApiProperty({ example: 'Мой магазин' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  @IsSafeText()
  name: string;

  @ApiProperty({
    enum: [
      'GROCERY',
      'CLOTHING',
      'ELECTRONICS',
      'HARDWARE',
      'PHARMACY',
      'OTHER',
    ],
  })
  @IsNotEmpty()
  @IsEnum([
    'GROCERY',
    'CLOTHING',
    'ELECTRONICS',
    'HARDWARE',
    'PHARMACY',
    'OTHER',
  ])
  category: string;

  @ApiPropertyOptional({ enum: ['TJS', 'USD', 'RUB'], default: 'TJS' })
  @IsOptional()
  @IsEnum(['TJS', 'USD', 'RUB'])
  currency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @IsSafeText()
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^\+?\d{9,15}$/)
  phone?: string;
}
