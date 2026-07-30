import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { BannersService } from './banners.service';

@ApiTags('Banners')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/banners')
export class BannersController {
  constructor(private readonly bannersService: BannersService) {}

  @Get('active')
  @ApiOperation({
    summary: 'Get the currently active banner for this store, if any',
  })
  getActive(@Param('storeId') storeId: string) {
    return this.bannersService.getActiveBanner(storeId);
  }
}
