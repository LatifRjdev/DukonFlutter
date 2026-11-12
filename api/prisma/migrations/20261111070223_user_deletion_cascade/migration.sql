-- Account deletion is a Google Play requirement for any app with sign-in.
--
-- These three foreign keys were declared without onDelete, so Prisma emitted
-- ON DELETE RESTRICT and prisma.user.delete() failed with
-- "Foreign key constraint violated on the constraint: stores_ownerId_fkey".
--
-- Cascading from the owner is the intended semantics: for this product the
-- owner is the business, so "delete my account and data" means the stores go
-- with it. Everything beneath Store already cascades. The service layer
-- refuses the delete while an owned store still has other staff, so this
-- constraint never silently removes someone else's workplace.

ALTER TABLE "stores" DROP CONSTRAINT "stores_ownerId_fkey";
ALTER TABLE "stores" ADD CONSTRAINT "stores_ownerId_fkey"
  FOREIGN KEY ("ownerId") REFERENCES "users"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "staff" DROP CONSTRAINT "staff_userId_fkey";
ALTER TABLE "staff" ADD CONSTRAINT "staff_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "notifications" DROP CONSTRAINT "notifications_userId_fkey";
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;
