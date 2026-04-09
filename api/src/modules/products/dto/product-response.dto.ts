import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ProductResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  name: string;

  @ApiPropertyOptional()
  sku?: string;

  @ApiPropertyOptional()
  barcode?: string;

  @ApiPropertyOptional()
  description?: string;

  @ApiPropertyOptional()
  costPrice?: number;

  @ApiProperty()
  sellPrice: number;

  @ApiPropertyOptional()
  wholesalePrice?: number;

  @ApiProperty()
  quantity: number;

  @ApiProperty()
  minQuantity: number;

  @ApiProperty()
  unit: string;

  @ApiPropertyOptional()
  imageUrl?: string;

  @ApiProperty()
  isActive: boolean;

  @ApiProperty()
  createdAt: Date;

  @ApiPropertyOptional()
  category?: { id: string; name: string };

  @ApiPropertyOptional()
  supplier?: { id: string; name: string };
}
