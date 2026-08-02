-- CreateEnum
CREATE TYPE "SalesChannel" AS ENUM ('IN_STORE', 'ONLINE');

-- AlterTable
ALTER TABLE "sales" ADD COLUMN "channel" "SalesChannel" NOT NULL DEFAULT 'IN_STORE';
ALTER TABLE "sales" ADD COLUMN "externalOrderId" TEXT;

-- AlterTable
ALTER TABLE "subscription_plan_configs" ADD COLUMN "hasEcommerceIntegration" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "ecommerce_integrations" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "apiKey" TEXT NOT NULL,
    "outboundWebhookUrl" TEXT,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ecommerce_integrations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "external_product_mappings" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "externalProductId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "external_product_mappings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ecommerce_integrations_storeId_key" ON "ecommerce_integrations"("storeId");

-- CreateIndex
CREATE UNIQUE INDEX "ecommerce_integrations_apiKey_key" ON "ecommerce_integrations"("apiKey");

-- CreateIndex
CREATE INDEX "external_product_mappings_productId_idx" ON "external_product_mappings"("productId");

-- CreateIndex
CREATE UNIQUE INDEX "external_product_mappings_storeId_externalProductId_key" ON "external_product_mappings"("storeId", "externalProductId");

-- CreateIndex
CREATE UNIQUE INDEX "sales_storeId_externalOrderId_key" ON "sales"("storeId", "externalOrderId");

-- AddForeignKey
ALTER TABLE "ecommerce_integrations" ADD CONSTRAINT "ecommerce_integrations_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "external_product_mappings" ADD CONSTRAINT "external_product_mappings_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "external_product_mappings" ADD CONSTRAINT "external_product_mappings_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
