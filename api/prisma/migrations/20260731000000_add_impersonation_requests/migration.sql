-- CreateTable
CREATE TABLE "impersonation_requests" (
    "id" TEXT NOT NULL,
    "adminId" TEXT NOT NULL,
    "targetUserId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),

    CONSTRAINT "impersonation_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "impersonation_requests_targetUserId_idx" ON "impersonation_requests"("targetUserId");
