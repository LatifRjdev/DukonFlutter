import { Controller, Get, Put, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { RolesService } from './roles.service';
import { UpdatePermissionsDto } from './dto/update-permissions.dto';

@ApiTags('roles')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/roles')
export class RolesController {
  constructor(private rolesService: RolesService) {}

  @Get()
  @ApiOperation({ summary: 'Get all roles with permissions for this store' })
  getAllRoles(@Param('storeId') storeId: string) {
    return this.rolesService.getAllRoles(storeId);
  }

  @Get(':role/permissions')
  @ApiOperation({ summary: 'Get permissions for a specific role' })
  getRolePermissions(
    @Param('storeId') storeId: string,
    @Param('role') role: string,
  ) {
    return this.rolesService.getRolePermissions(storeId, role);
  }

  @Put(':role/permissions')
  @Permissions('roles.manage')
  @ApiOperation({ summary: 'Update permissions for a specific role' })
  updateRolePermissions(
    @Param('storeId') storeId: string,
    @Param('role') role: string,
    @Body() dto: UpdatePermissionsDto,
  ) {
    return this.rolesService.updateRolePermissions(storeId, role, dto);
  }
}
