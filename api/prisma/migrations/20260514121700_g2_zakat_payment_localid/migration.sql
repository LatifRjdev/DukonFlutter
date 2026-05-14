-- Z-P1-1: client-supplied UUID column for idempotent payment retries.
-- Existing rows keep localId = NULL; the unique constraint is per
-- (storeId, localId) so two distinct stores can independently use
-- the same client-side UUID without colliding (Postgres treats
-- multiple NULLs as distinct, so legacy rows are exempt).

ALTER TABLE "zakat_payments" ADD COLUMN "localId" TEXT;

CREATE UNIQUE INDEX "zakat_payments_storeId_localId_key"
  ON "zakat_payments"("storeId", "localId");
