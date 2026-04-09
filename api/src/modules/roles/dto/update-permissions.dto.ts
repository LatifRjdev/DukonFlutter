import { IsObject, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdatePermissionsDto {
  @ApiProperty({
    description: 'Map of permission names to granted status',
    example: {
      view_sales: true,
      create_sales: true,
      cancel_sales: false,
      view_profit: false,
      change_prices: false,
      manage_products: false,
      add_expenses: false,
      manage_customers: true,
      manage_staff: false,
      view_reports: false,
    },
  })
  @IsObject()
  permissions: Record<string, boolean>;
}
