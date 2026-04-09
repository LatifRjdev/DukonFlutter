import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class ImportProductsDto {
  @ApiPropertyOptional({ description: 'Default category for imported products' })
  @IsOptional()
  @IsUUID()
  defaultCategoryId?: string;

  @ApiPropertyOptional({ description: 'Default supplier for imported products' })
  @IsOptional()
  @IsUUID()
  defaultSupplierId?: string;
}
