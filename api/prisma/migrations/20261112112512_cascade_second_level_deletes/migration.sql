-- Account deletion, second level.
--
-- The previous migration made every foreign key into `stores` cascade, which
-- was necessary but not sufficient: the tables that hang off those children
-- were still ON DELETE RESTRICT, so the cascade stopped one level down. Any
-- store with a single sale has `sale_items`, and a store with a subscription
-- payment has `payments` — either was enough to make deleting the owner fail.
--
-- All 13 remaining RESTRICT keys cascade now. They are all child rows of data
-- that is being destroyed anyway: a sale_item without its sale, or a payment
-- without its subscription, is not a record of anything.
--
-- One of them was load-bearing elsewhere. `supplier_payments -> suppliers`
-- RESTRICT was what stopped SuppliersService.remove() erasing a supplier's
-- financial history, so that guarantee moved into the service as an explicit
-- check in the same commit — where it can also say why it refused, instead of
-- surfacing a raw constraint error.
ALTER TABLE "debt_payments" DROP CONSTRAINT "debt_payments_saleId_fkey";
ALTER TABLE "debt_payments" ADD CONSTRAINT "debt_payments_saleId_fkey" FOREIGN KEY ("saleId") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "deliveries" DROP CONSTRAINT "deliveries_saleId_fkey";
ALTER TABLE "deliveries" ADD CONSTRAINT "deliveries_saleId_fkey" FOREIGN KEY ("saleId") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "external_product_mappings" DROP CONSTRAINT "external_product_mappings_productId_fkey";
ALTER TABLE "external_product_mappings" ADD CONSTRAINT "external_product_mappings_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "inventory_count_items" DROP CONSTRAINT "inventory_count_items_productId_fkey";
ALTER TABLE "inventory_count_items" ADD CONSTRAINT "inventory_count_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "inventory_items" DROP CONSTRAINT "inventory_items_productId_fkey";
ALTER TABLE "inventory_items" ADD CONSTRAINT "inventory_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "inventory_items" DROP CONSTRAINT "inventory_items_inventoryId_fkey";
ALTER TABLE "inventory_items" ADD CONSTRAINT "inventory_items_inventoryId_fkey" FOREIGN KEY ("inventoryId") REFERENCES "inventories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "payments" DROP CONSTRAINT "payments_subscriptionId_fkey";
ALTER TABLE "payments" ADD CONSTRAINT "payments_subscriptionId_fkey" FOREIGN KEY ("subscriptionId") REFERENCES "subscriptions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "payrolls" DROP CONSTRAINT "payrolls_staffId_fkey";
ALTER TABLE "payrolls" ADD CONSTRAINT "payrolls_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "payrolls" DROP CONSTRAINT "payrolls_payrollPeriodId_fkey";
ALTER TABLE "payrolls" ADD CONSTRAINT "payrolls_payrollPeriodId_fkey" FOREIGN KEY ("payrollPeriodId") REFERENCES "payroll_periods"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "sale_items" DROP CONSTRAINT "sale_items_productId_fkey";
ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "shifts" DROP CONSTRAINT "shifts_staffId_fkey";
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "stock_movements" DROP CONSTRAINT "stock_movements_productId_fkey";
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "supplier_payments" DROP CONSTRAINT "supplier_payments_supplierId_fkey";
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
