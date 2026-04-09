-- CreateEnum
CREATE TYPE "ShiftStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "PayrollStatus" AS ENUM ('DRAFT', 'CALCULATED', 'PARTIALLY_PAID', 'PAID');

-- CreateEnum
CREATE TYPE "AdjustmentType" AS ENUM ('BONUS', 'DEDUCTION');

-- AlterTable
ALTER TABLE "shifts" ADD COLUMN     "cardSales" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "cashSales" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "cashWithdrawals" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "debtSales" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "returnsCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "returnsTotal" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "status" "ShiftStatus" NOT NULL DEFAULT 'OPEN';

-- CreateTable
CREATE TABLE "role_permissions" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "role" "StaffRole" NOT NULL,
    "permission" TEXT NOT NULL,
    "isGranted" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payroll_periods" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "month" INTEGER NOT NULL,
    "year" INTEGER NOT NULL,
    "status" "PayrollStatus" NOT NULL DEFAULT 'DRAFT',
    "totalAmount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "paidAmount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payroll_periods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payrolls" (
    "id" TEXT NOT NULL,
    "payrollPeriodId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "baseSalary" DECIMAL(12,2) NOT NULL,
    "commission" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "commissionRate" DECIMAL(5,2),
    "salesTotal" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "shiftsWorked" INTEGER NOT NULL DEFAULT 0,
    "shiftsExpected" INTEGER NOT NULL DEFAULT 26,
    "totalAmount" DECIMAL(12,2) NOT NULL,
    "isPaid" BOOLEAN NOT NULL DEFAULT false,
    "paidAt" TIMESTAMP(3),
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payrolls_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payroll_adjustments" (
    "id" TEXT NOT NULL,
    "payrollId" TEXT NOT NULL,
    "type" "AdjustmentType" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "description" TEXT NOT NULL,
    "date" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payroll_adjustments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "role_permissions_storeId_role_permission_key" ON "role_permissions"("storeId", "role", "permission");

-- CreateIndex
CREATE UNIQUE INDEX "payroll_periods_storeId_month_year_key" ON "payroll_periods"("storeId", "month", "year");

-- CreateIndex
CREATE UNIQUE INDEX "payrolls_payrollPeriodId_staffId_key" ON "payrolls"("payrollPeriodId", "staffId");

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payroll_periods" ADD CONSTRAINT "payroll_periods_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payrolls" ADD CONSTRAINT "payrolls_payrollPeriodId_fkey" FOREIGN KEY ("payrollPeriodId") REFERENCES "payroll_periods"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payrolls" ADD CONSTRAINT "payrolls_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payroll_adjustments" ADD CONSTRAINT "payroll_adjustments_payrollId_fkey" FOREIGN KEY ("payrollId") REFERENCES "payrolls"("id") ON DELETE CASCADE ON UPDATE CASCADE;
