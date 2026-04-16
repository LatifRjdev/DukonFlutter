import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, Matches } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({ example: '+992901234567' })
  @IsString()
  @Matches(/^\+992\d{9}$/, {
    message: 'Неверный формат номера телефона',
  })
  phone: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6, { message: 'Код должен содержать 6 цифр' })
  code: string;
}
