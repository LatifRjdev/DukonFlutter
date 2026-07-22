import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsBoolean, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

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

  @ApiPropertyOptional({
    description:
      'Days without a sale before a product is flagged as slow-moving',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  daysWithoutSaleThreshold?: number;

  @ApiPropertyOptional({
    description:
      'Minimum % of the batch still unsold to trigger a slow-moving alert',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  remainingPercentThreshold?: number;
}
