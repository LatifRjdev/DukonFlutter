import { Controller, Get, Post, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { PayrollService } from './payroll.service';
import { CalculatePayrollDto } from './dto/calculate-payroll.dto';
import { CreateAdjustmentDto } from './dto/create-adjustment.dto';

@ApiTags('Payroll')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/payroll')
export class PayrollController {
  constructor(private payrollService: PayrollService) {}

  @Post('calculate')
  @Permissions('payroll.manage')
  @ApiOperation({ summary: 'Calculate payroll for a month/year' })
  calculate(@Param('storeId') storeId: string, @Body() dto: CalculatePayrollDto) {
    return this.payrollService.calculate(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List payroll periods' })
  findAll(@Param('storeId') storeId: string) {
    return this.payrollService.findAll(storeId);
  }

  @Get(':periodId')
  @ApiOperation({ summary: 'Get payroll period detail' })
  findOne(@Param('storeId') storeId: string, @Param('periodId') periodId: string) {
    return this.payrollService.findOne(storeId, periodId);
  }

  @Post(':periodId/adjustments')
  @Permissions('payroll.manage')
  @ApiOperation({ summary: 'Add payroll adjustment' })
  addAdjustment(
    @Param('storeId') storeId: string,
    @Param('periodId') periodId: string,
    @Body() dto: CreateAdjustmentDto,
  ) {
    return this.payrollService.addAdjustment(storeId, periodId, dto);
  }

  @Delete(':periodId/adjustments/:adjustmentId')
  @Permissions('payroll.manage')
  @ApiOperation({ summary: 'Delete payroll adjustment' })
  removeAdjustment(
    @Param('storeId') storeId: string,
    @Param('periodId') periodId: string,
    @Param('adjustmentId') adjustmentId: string,
  ) {
    return this.payrollService.removeAdjustment(storeId, periodId, adjustmentId);
  }

  @Post(':periodId/pay/:payrollId')
  @Permissions('payroll.pay')
  @ApiOperation({ summary: 'Mark individual payroll as paid' })
  payOne(
    @Param('storeId') storeId: string,
    @Param('periodId') periodId: string,
    @Param('payrollId') payrollId: string,
  ) {
    return this.payrollService.payOne(storeId, periodId, payrollId);
  }

  @Post(':periodId/pay-all')
  @Permissions('payroll.pay')
  @ApiOperation({ summary: 'Mark all payrolls in period as paid' })
  payAll(@Param('storeId') storeId: string, @Param('periodId') periodId: string) {
    return this.payrollService.payAll(storeId, periodId);
  }
}
