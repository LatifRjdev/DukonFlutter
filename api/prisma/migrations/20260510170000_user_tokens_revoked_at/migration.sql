-- F.1: track when a user's tokens were last revoked (password change /
-- admin-force-logout). JWT strategies reject tokens with iat <= this.
ALTER TABLE "users" ADD COLUMN "tokensRevokedAt" TIMESTAMP(3);
