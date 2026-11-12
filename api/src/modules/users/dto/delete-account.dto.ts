import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class DeleteAccountDto {
  @ApiProperty({
    description:
      'Current password. Required so the account cannot be destroyed from ' +
      'an unlocked device left unattended.',
    minLength: 6,
  })
  @IsString()
  @MinLength(6)
  password!: string;
}
