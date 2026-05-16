-- Spec E A.2: cash-on-hand for zakat calculation.
-- Default 0 so existing rows compute correctly until merchant
-- fills it in. CHECK constraint matches the other zakat money
-- columns.
ALTER TABLE "zakat_settings" ADD COLUMN "cashOnHand" DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "zakat_settings"
  ADD CONSTRAINT zakat_settings_cash_on_hand_non_negative
    CHECK ("cashOnHand" >= 0);
