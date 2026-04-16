import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class ForgotPasswordDto {
  @ApiProperty({ example: '+992901234567' })
  @IsString()
  @Matches(/^\+992\d{9}$/, {
    message: 'Неверный формат номера телефона',
  })
  phone: string;
}
