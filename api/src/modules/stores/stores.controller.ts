import {
  Controller,
  Delete,
  Get,
  Post,
  Put,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiResponse,
} from '@nestjs/swagger';
import { StoresService } from './stores.service';
import { CreateStoreDto } from './dto/create-store.dto';
import { UpdateStoreDto } from './dto/update-store.dto';
import { StoreResponseDto } from './dto/store-response.dto';
import { ReceiptTemplateDto } from './dto/receipt-template.dto';
import { assertNonEmptyDto } from '../../common/validators/non-empty-dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
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
  async create(@CurrentUser('id') userId: string, @Body() dto: CreateStoreDto) {
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
  @UseGuards(StoreAccessGuard, PermissionsGuard)
  @Permissions('store.manage')
  @ApiOperation({ summary: 'Update store' })
  @ApiResponse({ status: 200, type: StoreResponseDto })
  async update(@Param('storeId') storeId: string, @Body() dto: UpdateStoreDto) {
    return this.storesService.update(storeId, dto);
  }

  @Delete(':storeId')
  @UseGuards(StoreAccessGuard, PermissionsGuard)
  @Permissions('store.manage')
  @ApiOperation({ summary: 'Soft-delete store (sets isActive=false)' })
  @ApiResponse({ status: 200, type: StoreResponseDto })
  async remove(@Param('storeId') storeId: string) {
    return this.storesService.softDelete(storeId);
  }

  @Get(':storeId/receipt-template')
  @UseGuards(StoreAccessGuard)
  @ApiOperation({ summary: 'Get receipt template for store' })
  async getReceiptTemplate(@Param('storeId') storeId: string) {
    return this.storesService.getReceiptTemplate(storeId);
  }

  @Put(':storeId/receipt-template')
  @UseGuards(StoreAccessGuard, PermissionsGuard)
  @Permissions('store.manage')
  @ApiOperation({ summary: 'Update receipt template for store' })
  async updateReceiptTemplate(
    @Param('storeId') storeId: string,
    @Body() dto: ReceiptTemplateDto,
  ) {
    // Carryover P2: reject {} so a stray PUT can't silently wipe the
    // template back to defaults.
    assertNonEmptyDto(dto, 'receipt template');
    return this.storesService.updateReceiptTemplate(storeId, dto);
  }
}
