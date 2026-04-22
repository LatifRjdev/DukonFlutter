import { ApiProperty } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';
import { DeliveryStatus } from '@prisma/client';

export class UpdateDeliveryStatusDto {
  @ApiProperty({ enum: DeliveryStatus, description: 'New delivery status' })
  @IsEnum(DeliveryStatus)
  status: DeliveryStatus;
}
