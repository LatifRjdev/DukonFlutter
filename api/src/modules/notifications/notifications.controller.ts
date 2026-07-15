import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { NotificationsService } from './notifications.service';
import { SaveFcmTokenDto } from './dto/save-fcm-token.dto';
import { NotificationQueryDto } from './dto/notification-query.dto';
import { NotificationSettingsDto } from './dto/notification-settings.dto';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  /**
   * Register / refresh the FCM device token for the authenticated user.
   * Called by the mobile app on login and whenever the FCM token rotates.
   */
  @Post('users/me/fcm-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Save or update FCM push token for current user' })
  async saveFcmToken(
    @CurrentUser('id') userId: string,
    @Body() dto: SaveFcmTokenDto,
  ): Promise<void> {
    await this.notificationsService.saveFcmToken(
      userId,
      dto.token,
      dto.platform,
    );
  }

  /**
   * Paginated notification history for a store.
   * Filters to the current user so staff only see their own notifications.
   */
  @Get('stores/:storeId/notifications')
  @UseGuards(StoreAccessGuard)
  @ApiOperation({
    summary: 'Get paginated notification history for store+user',
  })
  getNotifications(
    @Param('storeId') storeId: string,
    @CurrentUser('id') userId: string,
    @Query() query: NotificationQueryDto,
  ) {
    return this.notificationsService.getNotifications(storeId, userId, query);
  }

  /**
   * Mark a specific notification as read.
   */
  @Put('stores/:storeId/notifications/:id/read')
  @UseGuards(StoreAccessGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Mark notification as read' })
  async markAsRead(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
  ): Promise<void> {
    await this.notificationsService.markAsRead(storeId, id);
  }

  /**
   * Fetch which notification types are enabled for this store.
   */
  @Get('stores/:storeId/notifications/settings')
  @UseGuards(StoreAccessGuard)
  @ApiOperation({ summary: 'Get notification preferences for store' })
  getSettings(@Param('storeId') storeId: string) {
    return this.notificationsService.getNotificationSettings(storeId);
  }

  /**
   * Save which notification types are enabled for this store.
   * Stored in store.settings.notifications JSON.
   */
  @Put('stores/:storeId/notifications/settings')
  @UseGuards(StoreAccessGuard, SubscriptionGuard)
  @RequiresFeature('hasAllPush')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Update notification preferences for store' })
  async saveSettings(
    @Param('storeId') storeId: string,
    @Body() dto: NotificationSettingsDto,
  ): Promise<void> {
    await this.notificationsService.saveNotificationSettings(storeId, dto);
  }
}
