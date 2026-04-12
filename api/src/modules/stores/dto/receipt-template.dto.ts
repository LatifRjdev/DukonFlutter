import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsBoolean } from 'class-validator';

export class ReceiptTemplateDto {
  @ApiPropertyOptional({ description: 'Store name shown on receipt' })
  @IsOptional()
  @IsString()
  storeName?: string;

  @ApiPropertyOptional({ description: 'Address line on receipt' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ description: 'Phone number on receipt' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ description: 'Footer message / thank-you note' })
  @IsOptional()
  @IsString()
  footer?: string;

  @ApiPropertyOptional({ description: 'Show store logo on receipt' })
  @IsOptional()
  @IsBoolean()
  showLogo?: boolean;

  @ApiPropertyOptional({ description: 'Show barcode on receipt' })
  @IsOptional()
  @IsBoolean()
  showBarcode?: boolean;

  @ApiPropertyOptional({ description: 'Custom header text' })
  @IsOptional()
  @IsString()
  header?: string;

  @ApiPropertyOptional({ description: 'Tax ID / TIN shown on receipt' })
  @IsOptional()
  @IsString()
  taxId?: string;
}
