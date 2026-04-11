import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { ZakatService } from './zakat.service';
import { UpsertZakatSettingsDto } from './dto/upsert-zakat-settings.dto';
import { CreateZakatPaymentDto } from './dto/create-zakat-payment.dto';

@ApiTags('Zakat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/zakat')
export class ZakatController {
  constructor(private zakatService: ZakatService) {}

  @Get('calculate')
  @ApiOperation({ summary: 'Calculate zakat for store' })
  calculate(@Param('storeId') storeId: string) {
    return this.zakatService.calculate(storeId);
  }

  @Get('settings')
  @ApiOperation({ summary: 'Get zakat settings' })
  getSettings(@Param('storeId') storeId: string) {
    return this.zakatService.getSettings(storeId);
  }

  @Post('settings')
  @Permissions('zakat.manage')
  @ApiOperation({ summary: 'Create or update zakat settings' })
  upsertSettings(
    @Param('storeId') storeId: string,
    @Body() dto: UpsertZakatSettingsDto,
  ) {
    return this.zakatService.upsertSettings(storeId, dto);
  }

  @Get('payments')
  @ApiOperation({ summary: 'List zakat payments' })
  getPayments(@Param('storeId') storeId: string) {
    return this.zakatService.getPayments(storeId);
  }

  @Post('payments')
  @Permissions('zakat.manage')
  @ApiOperation({ summary: 'Record zakat payment' })
  createPayment(
    @Param('storeId') storeId: string,
    @Body() dto: CreateZakatPaymentDto,
  ) {
    return this.zakatService.createPayment(storeId, dto);
  }
}
