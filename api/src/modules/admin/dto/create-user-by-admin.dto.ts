import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsBoolean,
  IsEnum,
  Matches,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { IsStrongPassword } from '../../../common/validators/strong-password.validator';
import { IsSafeText } from '../../../common/validators/safe-text.validator';

const STORE_CATEGORIES = [
  'GROCERY',
  'CLOTHING',
  'ELECTRONICS',
  'HARDWARE',
  'PHARMACY',
  'OTHER',
];

export class CreateUserByAdminDto {
  @ApiProperty({ example: 'Али Рахимов' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(80)
  @IsSafeText()
  name: string;

  @ApiProperty({ example: '+992901234567' })
  @IsNotEmpty()
  @Matches(/^\+992\d{9}$/, {
    message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)',
  })
  phone: string;

  @ApiPropertyOptional({ example: 'ali@example.com' })
  @IsOptional()
  @IsString()
  email?: string;

  @ApiPropertyOptional({
    description:
      'If omitted, a strong password is generated server-side and returned once in the response.',
    example: 'CorrectHorseBatteryStaple8',
  })
  @IsOptional()
  @IsStrongPassword(['phone', 'email'])
  password?: string;

  @ApiPropertyOptional({
    description:
      'Also create a first store for this user in the same request.',
  })
  @IsOptional()
  @IsBoolean()
  createStore?: boolean;

  @ApiPropertyOptional({ example: 'Мой магазин' })
  @ValidateIf((o) => o.createStore === true)
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  @IsSafeText()
  storeName?: string;

  @ApiPropertyOptional({ enum: STORE_CATEGORIES })
  @ValidateIf((o) => o.createStore === true)
  @IsNotEmpty()
  @IsEnum(STORE_CATEGORIES)
  storeCategory?: string;

  @ApiPropertyOptional({ enum: ['TJS', 'USD', 'RUB'], default: 'TJS' })
  @IsOptional()
  @IsEnum(['TJS', 'USD', 'RUB'], {
    message: 'storeCurrency must be one of: TJS, USD, RUB',
  })
  storeCurrency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @IsSafeText()
  storeAddress?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^\+?\d{9,15}$/)
  storePhone?: string;
}
