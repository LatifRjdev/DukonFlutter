-- CreateIndex
CREATE UNIQUE INDEX "external_product_mappings_storeId_productId_key" ON "external_product_mappings"("storeId", "productId");
