import {
  Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { ExpenseQueryDto } from './dto/expense-query.dto';

@ApiTags('Expenses')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/expenses')
export class ExpensesController {
  constructor(private expensesService: ExpensesService) {}

  @Post()
  @ApiOperation({ summary: 'Create expense' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateExpenseDto) {
    return this.expensesService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List expenses with filters' })
  findAll(@Param('storeId') storeId: string, @Query() query: ExpenseQueryDto) {
    return this.expensesService.findAll(storeId, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get expense details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.expensesService.findOne(storeId, id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update expense' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateExpenseDto,
  ) {
    return this.expensesService.update(storeId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete expense' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.expensesService.remove(storeId, id);
  }
}
