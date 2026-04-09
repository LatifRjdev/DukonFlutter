/*
  Warnings:

  - Added the required column `updatedAt` to the `expenses` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "expenses" ADD COLUMN     "notes" TEXT,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- CreateTable
CREATE TABLE "zakat_settings" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "nisabGold" DECIMAL(12,2) NOT NULL DEFAULT 85,
    "nisabSilver" DECIMAL(12,2) NOT NULL DEFAULT 595,
    "nisabCurrency" "Currency" NOT NULL DEFAULT 'TJS',
    "nisabAmount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "haulStartDate" TIMESTAMP(3),
    "zakatRate" DECIMAL(5,2) NOT NULL DEFAULT 2.5,
    "includeStock" BOOLEAN NOT NULL DEFAULT true,
    "includeCash" BOOLEAN NOT NULL DEFAULT true,
    "includeDebts" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "zakat_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "zakat_payments" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "totalAssets" DECIMAL(12,2) NOT NULL,
    "zakatDue" DECIMAL(12,2) NOT NULL,
    "breakdown" JSONB NOT NULL,
    "notes" TEXT,
    "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "zakat_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "supplier_payments" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "method" "SalePaymentType" NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "supplier_payments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "zakat_settings_storeId_key" ON "zakat_settings"("storeId");

-- CreateIndex
CREATE INDEX "zakat_payments_storeId_paidAt_idx" ON "zakat_payments"("storeId", "paidAt");

-- CreateIndex
CREATE INDEX "supplier_payments_supplierId_createdAt_idx" ON "supplier_payments"("supplierId", "createdAt");

-- AddForeignKey
ALTER TABLE "zakat_settings" ADD CONSTRAINT "zakat_settings_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "zakat_payments" ADD CONSTRAINT "zakat_payments_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
