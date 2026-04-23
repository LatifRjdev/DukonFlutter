import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UserResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  phone: string;

  @ApiProperty()
  name: string;

  @ApiPropertyOptional()
  email?: string;

  @ApiPropertyOptional()
  avatar?: string;

  @ApiProperty()
  isAdmin: boolean;

  @ApiProperty()
  createdAt: Date;
}
