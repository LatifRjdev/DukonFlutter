import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUrl, IsBoolean, ValidateIf } from 'class-validator';
import { IsSafeWebhookUrl } from '../../../common/validators/safe-webhook-url.validator';

export class UpsertEcommerceIntegrationDto {
  @ApiPropertyOptional({
    example: 'https://my-shop.example.com/dukon-webhook',
    nullable: true,
    description: 'Set to null to clear a previously-configured webhook URL',
  })
  @IsOptional()
  @ValidateIf((o) => o.outboundWebhookUrl !== null)
  @IsUrl({ require_tld: false })
  // EcommerceOutboundService.postWithRetry does a bare server-side
  // fetch(url, ...) against whatever is configured here — without this,
  // a merchant could point the webhook at the cloud metadata endpoint,
  // localhost, or any other private-network target (SSRF).
  @IsSafeWebhookUrl()
  outboundWebhookUrl?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
