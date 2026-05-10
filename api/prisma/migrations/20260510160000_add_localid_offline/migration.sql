-- E.1, E.3: localId on Shift and DebtPayment for offline-replay idempotency.
-- The Sale model already has localId (existing migration), so this is parity.
ALTER TABLE "shifts" ADD COLUMN "localId" TEXT;
ALTER TABLE "debt_payments" ADD COLUMN "localId" TEXT;
