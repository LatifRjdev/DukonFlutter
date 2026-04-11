import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';
import { IsStrongPassword } from '../../../common/validators/strong-password.validator';

export class ChangePasswordDto {
  // currentPassword intentionally not length-checked — we don't want to
  // reject an old 6-char password at the validation layer; bcrypt.compare
  // in the service will reject it anyway if it is wrong.
  @ApiProperty()
  @IsString()
  currentPassword: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @IsStrongPassword(['currentPassword'])
  newPassword: string;
}
