-- DropForeignKey
ALTER TABLE "zakat_payments" DROP CONSTRAINT "zakat_payments_storeId_fkey";

-- DropForeignKey
ALTER TABLE "zakat_settings" DROP CONSTRAINT "zakat_settings_storeId_fkey";

-- AddForeignKey
ALTER TABLE "zakat_settings" ADD CONSTRAINT "zakat_settings_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "zakat_payments" ADD CONSTRAINT "zakat_payments_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- G.2 P1 fix: ensure money columns can't go negative
ALTER TABLE "zakat_settings"
  ADD CONSTRAINT zakat_settings_nisab_gold_non_negative CHECK ("nisabGold" >= 0),
  ADD CONSTRAINT zakat_settings_nisab_silver_non_negative CHECK ("nisabSilver" >= 0),
  ADD CONSTRAINT zakat_settings_nisab_amount_non_negative CHECK ("nisabAmount" >= 0),
  ADD CONSTRAINT zakat_settings_zakat_rate_in_range CHECK ("zakatRate" >= 0 AND "zakatRate" <= 100);

ALTER TABLE "zakat_payments"
  ADD CONSTRAINT zakat_payment_amount_non_negative CHECK ("amount" >= 0),
  ADD CONSTRAINT zakat_payment_total_assets_non_negative CHECK ("totalAssets" >= 0),
  ADD CONSTRAINT zakat_payment_zakat_due_non_negative CHECK ("zakatDue" >= 0);
