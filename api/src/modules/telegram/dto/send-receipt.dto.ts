import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsUUID } from 'class-validator';

export class SendReceiptDto {
  @ApiProperty({ description: 'Sale ID to send receipt for' })
  @IsString()
  @IsUUID()
  saleId: string;
}
