import { IsString } from 'class-validator';

export class LinkTelegramDto {
  @IsString()
  username: string;
}
