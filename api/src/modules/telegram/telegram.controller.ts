import {
  Controller,
  Post,
  Body,
  Param,
  Headers,
  UseGuards,
  HttpCode,
  HttpStatus,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { TelegramService } from './telegram.service';
import { SendReceiptDto } from './dto/send-receipt.dto';

@ApiTags('Telegram')
@Controller()
export class TelegramController {
  constructor(
    private telegramService: TelegramService,
    private configService: ConfigService,
  ) {}

  /**
   * Telegram webhook — receives Update objects from Telegram servers.
   *
   * Telegram supports a per-webhook secret token: when registered with
   * setWebhook(secret_token=...), every callback carries the
   * X-Telegram-Bot-Api-Secret-Token header. We verify it here so a
   * random attacker can't POST fake updates that drive bot side effects.
   * If TELEGRAM_WEBHOOK_SECRET is not set we accept all requests (dev mode).
   */
  @Post('telegram/webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Telegram bot webhook (called by Telegram, not by clients)',
  })
  handleWebhook(
    @Body() update: any,
    @Headers('x-telegram-bot-api-secret-token') secretHeader?: string,
  ) {
    const expected = this.configService.get<string>('TELEGRAM_WEBHOOK_SECRET');
    if (expected && secretHeader !== expected) {
      throw new ForbiddenException('Invalid webhook secret');
    }
    return this.telegramService.handleWebhook(update);
  }

  /**
   * Manually trigger sending a receipt to the customer's Telegram.
   * Requires store-scoped auth.
   */
  @Post('stores/:storeId/telegram/send-receipt')
  @UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)
  @RequiresFeature('hasTelegram')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Send sale receipt to customer via Telegram' })
  sendReceipt(@Param('storeId') storeId: string, @Body() dto: SendReceiptDto) {
    return this.telegramService.sendReceipt(dto.saleId, storeId);
  }
}
