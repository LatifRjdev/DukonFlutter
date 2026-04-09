import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsEnum, IsNumber } from 'class-validator';

export enum StaffRoleEnum {
  ADMIN = 'ADMIN',
  CASHIER = 'CASHIER',
  WAREHOUSE = 'WAREHOUSE',
}

export class CreateStaffDto {
  @ApiProperty()
  @IsString()
  name: string;

  @ApiProperty()
  @IsString()
  phone: string;

  @ApiProperty({ enum: StaffRoleEnum })
  @IsEnum(StaffRoleEnum)
  role: StaffRoleEnum;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  salary?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  commission?: number;
}
