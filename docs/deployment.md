# DukonPro Production Deployment Guide

## Prerequisites

| Tool        | Minimum Version |
|-------------|-----------------|
| Node.js     | 20+             |
| PostgreSQL  | 15+             |
| Redis       | 7+              |
| Flutter     | 3.24+           |
| Java (JDK)  | 17+ (for Android builds) |

## Backend Setup

### Environment Variables

Create a `.env` file in `api/` (never commit to version control):

| Variable           | Description                                    | Example                                  |
|--------------------|------------------------------------------------|------------------------------------------|
| `NODE_ENV`         | Environment mode                               | `production`                             |
| `PORT`             | Server port                                    | `3000`                                   |
| `DATABASE_URL`     | PostgreSQL connection string                   | `postgresql://user:pass@host:5432/dukon` |
| `REDIS_URL`        | Redis connection string                        | `redis://host:6379`                      |
| `JWT_SECRET`       | Secret for signing access tokens               | (random 64+ chars)                       |
| `JWT_REFRESH_SECRET` | Secret for signing refresh tokens            | (random 64+ chars)                       |
| `CORS_ORIGIN`      | Allowed frontend origins (comma-separated)     | `https://app.dukonpro.com`               |
| `SMS_API_KEY`      | SMS provider API key for OTP                   | (provider-specific)                      |

### Database Migration

```bash
cd api
npx prisma migrate deploy
```

### Start Command

```bash
cd api
npm run build
NODE_ENV=production node dist/main.js
```

For process management in production, use PM2 or systemd:

```bash
pm2 start dist/main.js --name dukonpro-api
```

## Mobile Build

### Android APK

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.dukonpro.com \
  --dart-define=ENV=production
```

### Android App Bundle (for Google Play)

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.dukonpro.com \
  --dart-define=ENV=production
```

### iOS

```bash
cd app
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.dukonpro.com \
  --dart-define=ENV=production
```

## Android Signing

1. Generate a keystore (once):

```bash
keytool -genkey -v -keystore dukonpro-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dukonpro
```

2. Create `app/android/key.properties` (do NOT commit):

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=dukonpro
storeFile=../../dukonpro-upload.jks
```

3. The `android/app/build.gradle.kts` is already configured to read from `key.properties` when present.

## HTTPS Enforcement

- All production API traffic MUST use HTTPS.
- The backend sets HSTS headers via Helmet (`max-age: 180 days`, `includeSubDomains`, `preload`).
- Use a reverse proxy (nginx, Caddy, or cloud load balancer) to terminate TLS.
- Obtain certificates via Let's Encrypt or your cloud provider.

Example nginx snippet:

```nginx
server {
    listen 443 ssl;
    server_name api.dukonpro.com;

    ssl_certificate     /etc/letsencrypt/live/api.dukonpro.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.dukonpro.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Security Checklist

Before going live, verify each item:

- [ ] **Rotate all secrets** -- generate fresh `JWT_SECRET`, `JWT_REFRESH_SECRET`, and database passwords for production
- [ ] **Set `CORS_ORIGIN`** -- never leave it empty in production; whitelist only your frontend domain(s)
- [ ] **Enable SSL/TLS** -- all traffic over HTTPS, no plain HTTP in production
- [ ] **Database access** -- restrict PostgreSQL to private network; no public-facing port
- [ ] **Redis access** -- require authentication; bind to localhost or private network
- [ ] **Remove Swagger in production** -- or protect `/api/docs` behind authentication
- [ ] **No secrets in source code** -- all credentials via environment variables
- [ ] **Android keystore backup** -- store the `.jks` file and passwords in a secure vault
- [ ] **Rate limiting** -- ensure OTP and login endpoints are rate-limited
- [ ] **Logging** -- structured logs without PII, tokens, or passwords
- [ ] **Backups** -- automated daily PostgreSQL backups with tested restore procedure
- [ ] **Monitoring** -- health check endpoint, uptime alerting, error tracking (e.g., Sentry)
