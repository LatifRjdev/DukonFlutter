import { ApiProperty } from '@nestjs/swagger';

export class DebtSaleSummaryDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  receiptNo: string;

  @ApiProperty()
  total: number;

  @ApiProperty()
  debtAmount: number;

  @ApiProperty()
  createdAt: Date;

  @ApiProperty()
  status: string;
}

export class CustomerDebtsSummaryDto {
  @ApiProperty()
  customerId: string;

  @ApiProperty()
  totalDebt: number;

  @ApiProperty({ type: [DebtSaleSummaryDto] })
  sales: DebtSaleSummaryDto[];
}
