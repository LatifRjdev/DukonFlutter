import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
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
  @ApiResponse({ status: 200, description: 'Order processed successfully (created or cancelled)' })
  @ApiResponse({
    status: 409,
    description:
      'Transient stock conflict — a concurrent in-store sale claimed the stock first. Safe to retry; see the Retry-After header for the suggested delay in seconds.',
  })
  @ApiResponse({
    status: 422,
    description:
      'Permanent rejection — no product mapping, insufficient stock, or totalAmount mismatch. Fix the underlying issue before retrying; retrying an unchanged payload will fail again.',
  })
  @ApiResponse({ status: 401, description: 'Invalid or disabled X-API-Key' })
  handleWebhook(
    @Param('storeId') storeId: string,
    @Headers('x-api-key') apiKey: string,
    @Body() dto: EcommerceWebhookDto,
  ) {
    return this.ordersService.handleWebhook(storeId, apiKey, dto);
  }
}
