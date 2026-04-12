import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsEnum, IsNotEmpty } from 'class-validator';

export enum FcmPlatform {
  ANDROID = 'ANDROID',
  IOS = 'IOS',
}

export class SaveFcmTokenDto {
  @ApiProperty({ description: 'Firebase Cloud Messaging device token' })
  @IsString()
  @IsNotEmpty()
  token: string;

  @ApiProperty({ enum: FcmPlatform })
  @IsEnum(FcmPlatform)
  platform: FcmPlatform;
}
