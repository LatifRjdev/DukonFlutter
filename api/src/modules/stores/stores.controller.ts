import { Controller, Get, Post, Put, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { StoresService } from './stores.service';
import { CreateStoreDto } from './dto/create-store.dto';
import { UpdateStoreDto } from './dto/update-store.dto';
import { StoreResponseDto } from './dto/store-response.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('stores')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('stores')
export class StoresController {
  constructor(private readonly storesService: StoresService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new store' })
  @ApiResponse({ status: 201, type: StoreResponseDto })
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateStoreDto,
  ) {
    return this.storesService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List all stores for current user' })
  @ApiResponse({ status: 200, type: [StoreResponseDto] })
  async findAll(@CurrentUser('id') userId: string) {
    return this.storesService.findAll(userId);
  }

  @Get(':storeId')
  @UseGuards(StoreAccessGuard)
  @ApiOperation({ summary: 'Get store by ID' })
  @ApiResponse({ status: 200, type: StoreResponseDto })
  async findOne(@Param('storeId') storeId: string) {
    return this.storesService.findOne(storeId);
  }

  @Put(':storeId')
  @UseGuards(StoreAccessGuard)
  @ApiOperation({ summary: 'Update store' })
  @ApiResponse({ status: 200, type: StoreResponseDto })
  async update(
    @Param('storeId') storeId: string,
    @Body() dto: UpdateStoreDto,
  ) {
    return this.storesService.update(storeId, dto);
  }
}
