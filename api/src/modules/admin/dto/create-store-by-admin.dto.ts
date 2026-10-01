import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsEnum,
  IsUUID,
  Matches,
  MaxLength,
} from 'class-validator';
import { IsSafeText } from '../../../common/validators/safe-text.validator';

const STORE_CATEGORIES = [
  'GROCERY',
  'CLOTHING',
  'ELECTRONICS',
  'HARDWARE',
  'PHARMACY',
  'OTHER',
];

export class CreateStoreByAdminDto {
  @ApiProperty({ description: 'Existing user who will own the store' })
  @IsNotEmpty()
  @IsUUID()
  ownerId: string;

  @ApiProperty({ example: 'Мой магазин' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  @IsSafeText()
  name: string;

  @ApiProperty({ enum: STORE_CATEGORIES })
  @IsNotEmpty()
  @IsEnum(STORE_CATEGORIES)
  category: string;

  @ApiPropertyOptional({ enum: ['TJS', 'USD', 'RUB'], default: 'TJS' })
  @IsOptional()
  @IsEnum(['TJS', 'USD', 'RUB'], {
    message: 'currency must be one of: TJS, USD, RUB',
  })
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
