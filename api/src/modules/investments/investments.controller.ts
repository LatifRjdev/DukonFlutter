import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { InvestmentsService } from './investments.service';
import { CreateInvestmentDto } from './dto/create-investment.dto';
import { UpdateInvestmentDto } from './dto/update-investment.dto';
import { InvestmentQueryDto } from './dto/investment-query.dto';

@ApiTags('Investments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/investments')
export class InvestmentsController {
  constructor(private investmentsService: InvestmentsService) {}

  @Post()
  @Permissions('investments.write')
  @ApiOperation({ summary: 'Create investment' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateInvestmentDto) {
    return this.investmentsService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List investments with filters' })
  findAll(
    @Param('storeId') storeId: string,
    @Query() query: InvestmentQueryDto,
  ) {
    return this.investmentsService.findAll(storeId, query);
  }

  @Get('summary')
  @ApiOperation({ summary: 'Get investments summary' })
  summary(@Param('storeId') storeId: string) {
    return this.investmentsService.summary(storeId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get investment details' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.investmentsService.findOne(storeId, id);
  }

  @Put(':id')
  @Permissions('investments.write')
  @ApiOperation({ summary: 'Update investment' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateInvestmentDto,
  ) {
    return this.investmentsService.update(storeId, id, dto);
  }

  @Delete(':id')
  @Permissions('investments.write')
  @ApiOperation({ summary: 'Delete investment' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.investmentsService.remove(storeId, id);
  }
}
