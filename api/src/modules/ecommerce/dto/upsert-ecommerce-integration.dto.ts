import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUrl, IsBoolean, ValidateIf } from 'class-validator';

export class UpsertEcommerceIntegrationDto {
  @ApiPropertyOptional({
    example: 'https://my-shop.example.com/dukon-webhook',
    nullable: true,
    description: 'Set to null to clear a previously-configured webhook URL',
  })
  @IsOptional()
  @ValidateIf((o) => o.outboundWebhookUrl !== null)
  @IsUrl({ require_tld: false })
  outboundWebhookUrl?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
