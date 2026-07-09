import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { CreateCustomerPaymentDto } from './dto/create-payment.dto';
import { LinkTelegramDto } from './dto/link-telegram.dto';

@ApiTags('Customers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/customers')
export class CustomersController {
  constructor(private customersService: CustomersService) {}

  @Post()
  @ApiOperation({ summary: 'Create customer' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateCustomerDto) {
    return this.customersService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List customers' })
  findAll(
    @Param('storeId') storeId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('search') search?: string,
  ) {
    return this.customersService.findAll(storeId, page || 1, limit || 20, search);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get customer details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.customersService.findOne(storeId, id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update customer' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
  ) {
    return this.customersService.update(storeId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Deactivate customer' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.customersService.remove(storeId, id);
  }

  @Get(':id/debts')
  @ApiOperation({ summary: 'Get customer debt sales' })
  getDebts(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.customersService.getDebts(storeId, id);
  }

  @Post(':id/payments')
  @ApiOperation({ summary: 'Accept debt payment from customer' })
  addPayment(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: CreateCustomerPaymentDto,
  ) {
    return this.customersService.addPayment(storeId, id, dto);
  }

  @Get(':id/payments')
  @ApiOperation({ summary: 'List customer debt payments' })
  getPayments(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.customersService.getPayments(storeId, id);
  }

  @Put(':id/telegram')
  @ApiOperation({ summary: 'Link customer Telegram account by @username' })
  linkTelegram(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: LinkTelegramDto,
  ) {
    return this.customersService.linkTelegram(storeId, id, dto.username);
  }
}
