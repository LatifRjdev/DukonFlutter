import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class TransferStoreDto {
  @ApiProperty({ description: 'ID of the new owner user' })
  @IsString()
  @IsNotEmpty()
  newOwnerId: string;
}
