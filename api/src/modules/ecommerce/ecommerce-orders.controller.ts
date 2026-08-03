import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { EcommerceOrdersService } from './ecommerce-orders.service';
import { EcommerceWebhookDto } from './dto/ecommerce-webhook.dto';

@ApiTags('Ecommerce')
@Controller('stores/:storeId/ecommerce')
export class EcommerceOrdersController {
  constructor(private readonly ordersService: EcommerceOrdersService) {}

  // No JwtAuthGuard — the caller is the merchant's own website, which has
  // no Dukon user session. Authenticated via the per-store X-API-Key
  // header instead (checked inside EcommerceOrdersService), mirroring
  // TelegramController's shared-secret webhook pattern but with a
  // per-store DB-stored key rather than one global env var.
  @Post('orders')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @ApiOperation({
    summary:
      'Inbound order.created / order.cancelled webhook from the merchant site',
  })
  handleWebhook(
    @Param('storeId') storeId: string,
    @Headers('x-api-key') apiKey: string,
    @Body() dto: EcommerceWebhookDto,
  ) {
    return this.ordersService.handleWebhook(storeId, apiKey, dto);
  }
}
