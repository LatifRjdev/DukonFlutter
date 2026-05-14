import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ZakatService } from './zakat.service';
import { UpsertZakatSettingsDto } from './dto/upsert-zakat-settings.dto';
import { CreateZakatPaymentDto } from './dto/create-zakat-payment.dto';
import { assertNonEmptyDto } from '../../common/validators/non-empty-dto';

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
    @CurrentUser('id') userId: string,
  ) {
    // Carryover P2: reject {} so an empty POST can't silently
    // overwrite zakat settings with defaults.
    assertNonEmptyDto(dto, 'zakat settings');
    // Z-P1-2: pass acting userId so the service can write an audit
    // log entry attributing the change.
    return this.zakatService.upsertSettings(storeId, dto, userId);
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
    @CurrentUser('id') userId: string,
  ) {
    // Z-P1-1 + Z-P1-2: service re-derives zakatDue server-side and
    // writes an audit log entry attributing the mutation.
    return this.zakatService.createPayment(storeId, dto, userId);
  }
}
