import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '+992901234567' })
  @IsNotEmpty()
  @Matches(/^\+992\d{9}$/, { message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)' })
  phone: string;

  @ApiProperty({ example: 'password123' })
  @IsNotEmpty()
  @IsString()
  password: string;
}
