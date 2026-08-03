import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUrl, IsBoolean } from 'class-validator';

export class UpsertEcommerceIntegrationDto {
  @ApiPropertyOptional({ example: 'https://my-shop.example.com/dukon-webhook' })
  @IsOptional()
  @IsUrl({ require_tld: false })
  outboundWebhookUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
