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
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { StaffService } from './staff.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';

@ApiTags('staff')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/staff')
export class StaffController {
  constructor(private staffService: StaffService) {}

  @Post()
  @Permissions('staff.manage')
  @ApiOperation({ summary: 'Create staff member' })
  @ApiResponse({
    status: 201,
    description: 'Staff member created successfully',
  })
  @ApiResponse({
    status: 409,
    description: 'Staff member already exists in this store',
  })
  create(@Param('storeId') storeId: string, @Body() dto: CreateStaffDto) {
    return this.staffService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List staff members' })
  @ApiResponse({
    status: 200,
    description: 'Staff list retrieved successfully',
  })
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
  @Permissions('staff.manage')
  @ApiOperation({ summary: 'Update staff member' })
  @ApiResponse({
    status: 200,
    description: 'Staff member updated successfully',
  })
  @ApiResponse({ status: 404, description: 'Staff member not found' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateStaffDto,
    @CurrentUser('id') callerUserId: string,
  ) {
    return this.staffService.update(storeId, id, dto, callerUserId);
  }

  @Delete(':id')
  @Permissions('staff.manage')
  @ApiOperation({ summary: 'Deactivate staff member' })
  @ApiResponse({ status: 200, description: 'Staff member deactivated' })
  @ApiResponse({ status: 404, description: 'Staff member not found' })
  remove(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @CurrentUser('id') callerUserId: string,
  ) {
    return this.staffService.remove(storeId, id, callerUserId);
  }
}
