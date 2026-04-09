---
description: Security rules for handling auth, tokens, and sensitive data
globs: "**/*.kt,**/*.swift,**/*.ts"
---

# Security Rules

- Tokens stored in Keychain (iOS) / EncryptedSharedPreferences (Android) — NEVER in plain SharedPreferences or UserDefaults
- Never log tokens, passwords, or PII
- API calls always over HTTPS in production
- Input validation at system boundaries (user input, API responses)
- SQL injection impossible with SQLDelight (parameterized queries) — don't bypass with raw SQL
- Phone numbers validated with +992 prefix for Tajikistan
- OTP codes: 6 digits, 60s expiry, rate limited
- Passwords: minimum 6 characters, hashed with bcrypt on backend
- No secrets in source code — use BuildConfig (Android) / Info.plist (iOS) / env vars
