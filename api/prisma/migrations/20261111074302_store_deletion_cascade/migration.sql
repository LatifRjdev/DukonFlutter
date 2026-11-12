-- Account deletion cascades from the owner down. The previous migration
-- opened User -> Store, but 20 of the 24 foreign keys pointing at `stores`
-- were still ON DELETE RESTRICT, so deleting an owner whose store held a
-- single product failed. Only four relations had been given an explicit
-- Cascade; the rest carried Prisma's default, which is Restrict when
-- onDelete is omitted — a default, not a decision.
--
-- Checked before writing this: nothing in the API hard-deletes a store.
-- DELETE /stores/:storeId is a soft delete (isActive=false) and
-- DELETE /admin/users/:id anonymises rather than removes. So this cascade is
-- reachable only from the new account-deletion path.

ALTER TABLE "categories" DROP CONSTRAINT "categories_storeId_fkey";
ALTER TABLE "categories" ADD CONSTRAINT "categories_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "customers" DROP CONSTRAINT "customers_storeId_fkey";
ALTER TABLE "customers" ADD CONSTRAINT "customers_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "deliveries" DROP CONSTRAINT "deliveries_storeId_fkey";
ALTER TABLE "deliveries" ADD CONSTRAINT "deliveries_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "discounts" DROP CONSTRAINT "discounts_storeId_fkey";
ALTER TABLE "discounts" ADD CONSTRAINT "discounts_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "ecommerce_integrations" DROP CONSTRAINT "ecommerce_integrations_storeId_fkey";
ALTER TABLE "ecommerce_integrations" ADD CONSTRAINT "ecommerce_integrations_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "expenses" DROP CONSTRAINT "expenses_storeId_fkey";
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "external_product_mappings" DROP CONSTRAINT "external_product_mappings_storeId_fkey";
ALTER TABLE "external_product_mappings" ADD CONSTRAINT "external_product_mappings_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "inventories" DROP CONSTRAINT "inventories_storeId_fkey";
ALTER TABLE "inventories" ADD CONSTRAINT "inventories_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "inventory_counts" DROP CONSTRAINT "inventory_counts_storeId_fkey";
ALTER TABLE "inventory_counts" ADD CONSTRAINT "inventory_counts_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "notifications" DROP CONSTRAINT "notifications_storeId_fkey";
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "payroll_periods" DROP CONSTRAINT "payroll_periods_storeId_fkey";
ALTER TABLE "payroll_periods" ADD CONSTRAINT "payroll_periods_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "products" DROP CONSTRAINT "products_storeId_fkey";
ALTER TABLE "products" ADD CONSTRAINT "products_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "role_permissions" DROP CONSTRAINT "role_permissions_storeId_fkey";
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "sales" DROP CONSTRAINT "sales_storeId_fkey";
ALTER TABLE "sales" ADD CONSTRAINT "sales_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "shifts" DROP CONSTRAINT "shifts_storeId_fkey";
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "staff" DROP CONSTRAINT "staff_storeId_fkey";
ALTER TABLE "staff" ADD CONSTRAINT "staff_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "subscriptions" DROP CONSTRAINT "subscriptions_storeId_fkey";
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "supplier_payments" DROP CONSTRAINT "supplier_payments_storeId_fkey";
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "suppliers" DROP CONSTRAINT "suppliers_storeId_fkey";
ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "sync_logs" DROP CONSTRAINT "sync_logs_storeId_fkey";
ALTER TABLE "sync_logs" ADD CONSTRAINT "sync_logs_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "stores"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

