import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';
import { IsStrongPassword } from '../../../common/validators/strong-password.validator';

export class ChangePasswordDto {
  // F9.1: accept both `currentPassword` (canonical) and `oldPassword`
  // (alias used by some clients). Transform collapses `oldPassword`
  // into `currentPassword` before downstream validation runs.
  //
  // Length check intentionally omitted — bcrypt.compare in the service
  // rejects a wrong value either way; we don't want to refuse an old
  // 6-char password at the validation layer.
  @ApiProperty()
  @Transform(({ value, obj }) => value ?? obj.oldPassword ?? '')
  @IsString()
  currentPassword: string;

  @ApiPropertyOptional({ description: 'Alias for currentPassword' })
  @IsOptional()
  @IsString()
  oldPassword?: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @IsStrongPassword(['currentPassword'])
  newPassword: string;
}
