import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { StaffService } from './staff.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';

@ApiTags('staff')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/staff')
export class StaffController {
  constructor(private staffService: StaffService) {}

  @Post()
  @ApiOperation({ summary: 'Create staff member' })
  @ApiResponse({ status: 201, description: 'Staff member created successfully' })
  @ApiResponse({ status: 409, description: 'Staff member already exists in this store' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateStaffDto) {
    return this.staffService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List staff members' })
  @ApiResponse({ status: 200, description: 'Staff list retrieved successfully' })
  findAll(
    @Param('storeId') storeId: string,
    @Query('search') search?: string,
    @Query('role') role?: string,
  ) {
    return this.staffService.findAll(storeId, search, role);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get staff member details' })
  @ApiResponse({ status: 200, description: 'Staff member details retrieved' })
  @ApiResponse({ status: 404, description: 'Staff member not found' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.staffService.findOne(storeId, id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update staff member' })
  @ApiResponse({ status: 200, description: 'Staff member updated successfully' })
  @ApiResponse({ status: 404, description: 'Staff member not found' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateStaffDto,
  ) {
    return this.staffService.update(storeId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Deactivate staff member' })
  @ApiResponse({ status: 200, description: 'Staff member deactivated' })
  @ApiResponse({ status: 404, description: 'Staff member not found' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.staffService.remove(storeId, id);
  }
}
