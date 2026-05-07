import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsEmail,
  IsDateString,
  Matches,
} from 'class-validator';

export class CreateCustomerDto {
  @ApiProperty()
  @IsString()
  name: string;

  // F5.1: align customer phone validation with the User register pipe.
  // Optional, but when supplied must be the +992XXXXXXXXX Tajik format
  // so Telegram-receipt lookup, debt-by-phone search, and SMS later all
  // hit a normalised value.
  @ApiPropertyOptional({ example: '+992909000000' })
  @IsOptional()
  @IsString()
  @Matches(/^\+992\d{9}$/, {
    message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)',
  })
  phone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  birthday?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}
