import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class UpsertProductMappingDto {
  // Empty string / omitted means "remove the mapping for this product" —
  // matches the mobile screen's single editable text field per product
  // (a later task): clearing the field and saving deletes the mapping.
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  externalProductId?: string;
}
