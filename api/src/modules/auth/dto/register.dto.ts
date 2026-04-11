import { ApiProperty } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';
import { IsStrongPassword } from '../../../common/validators/strong-password.validator';
import { IsSafeText } from '../../../common/validators/safe-text.validator';

export class RegisterDto {
  @ApiProperty({
    example: '\u0410\u043b\u0438 \u0420\u0430\u0445\u0438\u043c\u043e\u0432',
  })
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

  @ApiProperty({ example: 'CorrectHorseBatteryStaple8', minLength: 8 })
  @IsNotEmpty()
  @IsString()
  @IsStrongPassword(['phone', 'email'])
  password: string;

  @ApiProperty({ example: 'ali@example.com', required: false })
  @IsOptional()
  @IsString()
  email?: string;
}
