import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty } from 'class-validator';

export class RespondImpersonationDto {
  @ApiProperty({ enum: ['APPROVED', 'REJECTED'] })
  @IsNotEmpty()
  @IsIn(['APPROVED', 'REJECTED'])
  decision: 'APPROVED' | 'REJECTED';
}
