-- Spec B (Offline Parity): add localId for idempotent replay on
-- StockMovement / DebtPayment / SupplierPayment. Existing rows
-- keep localId = NULL; Postgres treats multiple NULLs as distinct
-- in a unique index, so legacy rows are exempt.

-- StockMovement: globally-unique localId (no storeId column).
ALTER TABLE "stock_movements" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "stock_movements_localId_key"
  ON "stock_movements"("localId");

-- DebtPayment: localId column already exists from a prior sprint;
-- only the unique constraint is missing.
CREATE UNIQUE INDEX "debt_payments_saleId_localId_key"
  ON "debt_payments"("saleId", "localId");

-- SupplierPayment: scope per store (matches Customer/Sale pattern).
ALTER TABLE "supplier_payments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "supplier_payments_storeId_localId_key"
  ON "supplier_payments"("storeId", "localId");
