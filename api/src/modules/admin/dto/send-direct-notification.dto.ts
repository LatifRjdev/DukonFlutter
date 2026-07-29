import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength, ValidateIf } from 'class-validator';

export class SendDirectNotificationDto {
  @ApiPropertyOptional({
    description:
      'Target a specific user account. Exactly one of userId/storeId must be set.',
  })
  @ValidateIf((o) => !o.storeId)
  @IsNotEmpty()
  @IsString()
  userId?: string;

  @ApiPropertyOptional({
    description:
      'Target every owner+staff of a store. Exactly one of userId/storeId must be set.',
  })
  @ValidateIf((o) => !o.userId)
  @IsNotEmpty()
  @IsString()
  storeId?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(200)
  title: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(1000)
  body: string;
}
