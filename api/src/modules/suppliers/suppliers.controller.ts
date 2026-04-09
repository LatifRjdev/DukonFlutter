import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SuppliersService } from './suppliers.service';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { CreateSupplierPaymentDto } from './dto/create-payment.dto';

@ApiTags('Suppliers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/suppliers')
export class SuppliersController {
  constructor(private suppliersService: SuppliersService) {}

  @Post()
  @ApiOperation({ summary: 'Create supplier' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateSupplierDto) {
    return this.suppliersService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List suppliers' })
  findAll(
    @Param('storeId') storeId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('search') search?: string,
  ) {
    return this.suppliersService.findAll(storeId, page || 1, limit || 20, search);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get supplier details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.suppliersService.findOne(storeId, id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update supplier' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateSupplierDto,
  ) {
    return this.suppliersService.update(storeId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete supplier' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.suppliersService.remove(storeId, id);
  }

  @Get(':id/debts')
  @ApiOperation({ summary: 'Get supplier debt info' })
  getDebts(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.suppliersService.getDebts(storeId, id);
  }

  @Post(':id/payments')
  @ApiOperation({ summary: 'Record payment to supplier' })
  addPayment(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: CreateSupplierPaymentDto,
  ) {
    return this.suppliersService.addPayment(storeId, id, dto);
  }

  @Get(':id/payments')
  @ApiOperation({ summary: 'List payments to supplier' })
  getPayments(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.suppliersService.getPayments(storeId, id);
  }
}
