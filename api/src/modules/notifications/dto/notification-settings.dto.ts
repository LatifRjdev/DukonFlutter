import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsBoolean } from 'class-validator';

export class NotificationSettingsDto {
  @ApiPropertyOptional({
    description: 'Alert when product stock falls below minimum',
  })
  @IsOptional()
  @IsBoolean()
  lowStockAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Notify on each new sale' })
  @IsOptional()
  @IsBoolean()
  newSaleAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Notify when a shift is closed' })
  @IsOptional()
  @IsBoolean()
  shiftClosedAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Notify when a delivery is completed' })
  @IsOptional()
  @IsBoolean()
  deliveryCompletedAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Send debt reminders to customers' })
  @IsOptional()
  @IsBoolean()
  debtReminderAlerts?: boolean;
}
