import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MinLength, Matches } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: '\u0410\u043b\u0438 \u0420\u0430\u0445\u0438\u043c\u043e\u0432' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: '+992901234567' })
  @IsNotEmpty()
  @Matches(/^\+992\d{9}$/, { message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)' })
  phone: string;

  @ApiProperty({ example: 'password123', minLength: 6 })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  password: string;

  @ApiProperty({ example: 'ali@example.com', required: false })
  @IsOptional()
  @IsString()
  email?: string;
}
