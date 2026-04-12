import {
  Controller,
  Post,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { TelegramService } from './telegram.service';
import { SendReceiptDto } from './dto/send-receipt.dto';

@ApiTags('Telegram')
@Controller()
export class TelegramController {
  constructor(private telegramService: TelegramService) {}

  /**
   * Telegram webhook — receives Update objects from Telegram servers.
   * No auth guard: Telegram sends unauthenticated POST requests here.
   */
  @Post('telegram/webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Telegram bot webhook (called by Telegram, not by clients)' })
  handleWebhook(@Body() update: any) {
    return this.telegramService.handleWebhook(update);
  }

  /**
   * Manually trigger sending a receipt to the customer's Telegram.
   * Requires store-scoped auth.
   */
  @Post('stores/:storeId/telegram/send-receipt')
  @UseGuards(JwtAuthGuard, StoreAccessGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Send sale receipt to customer via Telegram' })
  sendReceipt(
    @Param('storeId') storeId: string,
    @Body() dto: SendReceiptDto,
  ) {
    return this.telegramService.sendReceipt(dto.saleId, storeId);
  }
}
