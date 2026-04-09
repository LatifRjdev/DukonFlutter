import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CategoryResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  name: string;

  @ApiPropertyOptional()
  icon?: string;

  @ApiPropertyOptional()
  color?: string;

  @ApiProperty()
  sortOrder: number;

  @ApiPropertyOptional()
  parentId?: string;

  @ApiProperty()
  createdAt: Date;

  @ApiProperty({ description: 'Number of products in this category' })
  _count?: { products: number };
}
