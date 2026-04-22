# Admin Panel + Full Admin API + Deployment — Spec

**Date**: 2026-04-12
**Goal**: Complete admin control panel (Next.js), full admin API (18 new endpoints), and production deployment infrastructure.

---

## Part 1: Admin API — 6 New Modules

All admin endpoints require `JwtAuthGuard` + `AdminGuard` (user.isAdmin === true).

### 1.1 User Management

**Controller**: `AdminUsersController` — `@Controller('admin/users')`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/users` | List users. Filters: ?search=&isAdmin=&isActive=&page=&limit= |
| GET | `/admin/users/:id` | User detail: profile + stores + subscriptions + sales count |
| PUT | `/admin/users/:id/toggle-admin` | Toggle isAdmin flag |
| PUT | `/admin/users/:id/block` | Block user (isActive=false, delete all refresh tokens) |
| PUT | `/admin/users/:id/unblock` | Unblock user (isActive=true) |
| DELETE | `/admin/users/:id` | Soft-delete: isActive=false + anonymize phone/email |

### 1.2 Store Management

**Controller**: `AdminStoresController` — `@Controller('admin/stores')`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/stores` | List stores. Filters: ?search=&category=&isActive=&plan=&page=&limit=. Includes: owner name, subscription plan/status, products count, staff count |
| GET | `/admin/stores/:id` | Store detail: all data + stats (products, monthly sales, staff, last activity) |
| PUT | `/admin/stores/:id/suspend` | Suspend store (isActive=false) |
| PUT | `/admin/stores/:id/unsuspend` | Unsuspend store (isActive=true) |
| PUT | `/admin/stores/:id/transfer` | Transfer ownership: `{newOwnerId}`. Validates new user exists. |

### 1.3 Global Analytics

**Controller**: `AdminDashboardController` — `@Controller('admin/dashboard')`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/dashboard` | Metrics: totalUsers, totalStores, activeSubscriptions, expiredSubscriptions, trialCount, monthlyRevenue, newUsersThisMonth, newStoresThisMonth |
| GET | `/admin/revenue` | Revenue chart: ?period=week\|month\|year. Returns `[{date, revenue, paymentsCount}]` |
| GET | `/admin/dashboard/registrations` | Registration chart: ?period=month. Returns `[{date, users, stores}]` |

### 1.4 Plan Management

**Controller**: `AdminPlansController` — `@Controller('admin/plans')`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/plans` | All 3 plans with current prices and limits |
| PUT | `/admin/plans/:plan` | Update plan: partial update of price, limits, features |

### 1.5 Announcements

**Controller**: `AdminAnnouncementsController` — `@Controller('admin/announcements')`

**New Prisma model:**
```prisma
model Announcement {
  id             String    @id @default(uuid())
  title          String
  body           String
  targetPlan     SubscriptionPlan?
  targetStatus   SubscriptionStatus?
  sentBy         String
  recipientCount Int
  createdAt      DateTime  @default(now())

  @@map("announcements")
}
```

| Method | Path | Description |
|--------|------|-------------|
| POST | `/admin/announcements` | Send push: `{title, body, targetPlan?, targetStatus?}`. Filters recipients by plan/status. Saves record + sends FCM via NotificationService. |
| GET | `/admin/announcements` | History of sent announcements |

### 1.6 Audit Log

**New Prisma model:**
```prisma
model AuditLog {
  id         String   @id @default(uuid())
  userId     String
  action     String
  entityType String
  entityId   String?
  details    Json?
  ip         String?
  createdAt  DateTime @default(now())

  @@index([userId])
  @@index([action])
  @@index([createdAt])
  @@map("audit_logs")
}
```

**AuditInterceptor**: NestJS interceptor that auto-logs all POST/PUT/DELETE requests to `/admin/*` endpoints. Captures: userId, action (from route), entityType/entityId (from params), request body as details, IP from request.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/audit-log` | Action log. Filters: ?userId=&action=&entityType=&from=&to=&page=&limit= |

**Logged actions**: approve_payment, reject_payment, block_user, unblock_user, toggle_admin, suspend_store, unsuspend_store, transfer_store, change_plan, set_discount, extend_subscription, cancel_subscription, send_announcement, update_plan_config.

### API Summary

- **Existing admin endpoints**: 8 (subscriptions)
- **New admin endpoints**: 18
- **Total**: 26 admin endpoints
- **New Prisma models**: Announcement, AuditLog

---

## Part 2: Admin Panel — Next.js

### Tech Stack

| Component | Choice |
|-----------|--------|
| Framework | Next.js 15 (App Router) |
| UI | shadcn/ui + Tailwind CSS |
| Charts | Recharts |
| Tables | TanStack Table |
| State/Data | TanStack Query (React Query) |
| Auth | JWT in httpOnly cookie via `/auth/login` |

### Project Structure

Location: `admin/` directory in project root.

```
admin/
├── app/
│   ├── layout.tsx           ← sidebar + header
│   ├── page.tsx             ← dashboard (metrics + charts)
│   ├── login/page.tsx       ← phone + password login
│   ├── users/
│   │   ├── page.tsx         ← users table
│   │   └── [id]/page.tsx    ← user detail
│   ├── stores/
│   │   ├── page.tsx         ← stores table
│   │   └── [id]/page.tsx    ← store detail
│   ├── subscriptions/
│   │   ├── page.tsx         ← subscriptions + pending payments
│   │   └── plans/page.tsx   ← plan config editor
│   ├── announcements/page.tsx
│   └── audit-log/page.tsx
├── components/
│   ├── sidebar.tsx
│   ├── stats-card.tsx
│   ├── data-table.tsx
│   └── charts/
├── lib/
│   ├── api.ts               ← fetch wrapper with auth
│   └── types.ts
├── package.json
├── tailwind.config.ts
└── next.config.ts
```

### Pages

**Dashboard** (`/`):
- 8 metric cards: users, stores, active subs, trial, expired, monthly revenue, new users this week, new stores this week
- Revenue line chart (30 days)
- Registrations bar chart (30 days)
- Last 5 pending payments (quick access links)

**Users** (`/users`):
- DataTable: name, phone, email, stores count, isAdmin badge, isActive badge, registered date
- Search bar, filter chips (all/admin/blocked)
- Row actions: toggle admin, block/unblock
- Click row → user detail page (profile + stores list + subscription info)

**Stores** (`/stores`):
- DataTable: name, owner, category, plan badge, status badge, products count, monthly sales
- Search bar, filter dropdowns (category, plan, status)
- Row actions: suspend/unsuspend, transfer ownership (dialog with user search)
- Click row → store detail (stats cards + recent activity)

**Subscriptions** (`/subscriptions`):
- Two tabs: "All Subscriptions" / "Pending Payments"
- Pending tab: cards with store name, requested plan, amount, receipt image thumbnail, Approve/Reject buttons
- Approve → one click
- Reject → dialog with "Reason" text field
- All tab: DataTable with actions (extend, change plan, set discount, cancel)

**Plans** (`/subscriptions/plans`):
- 3 editable cards (START/BUSINESS/PREMIUM)
- Inline edit: price (number input), limits (number inputs, -1=unlimited), features (toggles)
- "Save" button per card

**Announcements** (`/announcements`):
- Form: title, body, target filter (all / by plan dropdown / by status dropdown)
- Preview: "Will be sent to ~N users"
- "Send" with confirmation dialog
- History table below

**Audit Log** (`/audit-log`):
- DataTable: date, user name, action badge, entity type, entity ID, IP
- Filters: action dropdown, user search, date range picker
- Infinite scroll pagination

### Auth Flow

1. Login page: phone + password → `POST /auth/login`
2. Response includes JWT tokens
3. Check `GET /users/me` → if `isAdmin === false` → show "Access denied" and logout
4. JWT stored in httpOnly cookie (set by Next.js API route)
5. Next.js middleware checks cookie on every route, redirects to /login if missing

---

## Part 3: Deployment

### Architecture

```
Hetzner VPS CX22 (2 vCPU, 4GB RAM, 40GB SSD) — ~€4.5/month
├── Docker Compose
│   ├── nginx (reverse proxy + SSL via Certbot)
│   │   ├── api.dukonpro.tj → api:4455
│   │   └── admin.dukonpro.tj → admin:3000
│   ├── api (NestJS backend) — port 4455
│   ├── admin (Next.js panel) — port 3000
│   ├── postgres:16-alpine — port 5432 (internal)
│   └── volumes: postgres_data, uploads, certbot
├── /data/uploads/ (receipt images, product photos)
└── /data/backups/ (daily DB backups)
```

### Domains

| Domain | Purpose |
|--------|---------|
| `api.dukonpro.tj` | NestJS API (Flutter app connects here) |
| `admin.dukonpro.tj` | Admin Panel (Next.js) |
| `dukonpro.tj` | Landing page (future) |

### Docker Compose

```yaml
services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: dokonpro
      POSTGRES_USER: dokonpro
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    restart: always

  api:
    build: ./api
    depends_on: [postgres]
    environment:
      DATABASE_URL: postgresql://dokonpro:${DB_PASSWORD}@postgres:5432/dokonpro
      JWT_ACCESS_SECRET: ${JWT_ACCESS_SECRET}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET}
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
      FIREBASE_SERVICE_ACCOUNT: ${FIREBASE_SERVICE_ACCOUNT}
    volumes:
      - uploads:/app/uploads
    restart: always

  admin:
    build: ./admin
    depends_on: [api]
    environment:
      NEXT_PUBLIC_API_URL: https://api.dukonpro.tj
    restart: always

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - certbot_data:/etc/letsencrypt
    depends_on: [api, admin]
    restart: always

volumes:
  postgres_data:
  uploads:
  certbot_data:
```

### Deployment Steps

**Prerequisites:**
1. Register domain `dukonpro.tj` at nic.tj (~$15/year)
2. Create Hetzner account, provision CX22 server (~€4.5/month)
3. Point DNS A records: `api.dukonpro.tj` → server IP, `admin.dukonpro.tj` → server IP

**Server Setup (one-time):**
```bash
# SSH in
ssh root@SERVER_IP

# System
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh
apt install docker-compose-plugin certbot -y

# User
adduser dokonpro
usermod -aG docker dokonpro

# Firewall
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw enable

# SSL
certbot certonly --standalone -d api.dukonpro.tj -d admin.dukonpro.tj
```

**First Deploy:**
```bash
su - dokonpro
git clone https://github.com/LatifRjdev/DukonFlutter.git dokonpro
cd dokonpro
cp api/.env.example .env
nano .env  # fill all secrets
docker compose up -d
docker compose exec api npx prisma migrate deploy
docker compose exec api npx ts-node scripts/create-admin.ts
```

**Updates:**
```bash
ssh dokonpro@SERVER_IP
cd dokonpro && git pull
docker compose build api admin
docker compose up -d api admin
docker compose exec api npx prisma migrate deploy
```

### Backups

Daily PostgreSQL backup via cron:
```
0 3 * * * docker compose exec -T postgres pg_dump -U dokonpro dokonpro | gzip > /data/backups/db-$(date +\%Y\%m\%d).sql.gz
0 4 * * * find /data/backups -name "*.sql.gz" -mtime +30 -delete
```

### Monitoring

| What | Tool | Cost |
|------|------|------|
| Uptime | UptimeRobot (free: 50 monitors) | $0 |
| Logs | `docker compose logs -f api` | $0 |
| Crashes | Firebase Crashlytics (Flutter) | $0 |
| Metrics | Admin Dashboard (built-in) | $0 |

### Cost Summary

| Item | Cost |
|------|------|
| Hetzner VPS CX22 | ~$5/month |
| Domain dukonpro.tj | ~$1.25/month ($15/year) |
| Hetzner snapshots | ~$1/month |
| SSL (Let's Encrypt) | $0 |
| **Total** | **~$7.25/month** |

### Scaling Path

| Stage | When | Action |
|-------|------|--------|
| 50+ stores | ~6 months | Upgrade VPS to CX32 (4 vCPU, 8GB) — €8/month |
| 200+ stores | ~1 year | Move PostgreSQL to Hetzner Managed DB — €15/month |
| 500+ stores | ~2 years | Add 2nd VPS + load balancer, Redis for caching |

---

## Implementation Order

1. **Admin API** (backend) — 18 new endpoints, 2 Prisma models, AuditInterceptor
2. **Admin Panel** (Next.js) — new project in `admin/` directory
3. **Deployment** — Dockerfiles, docker-compose, nginx config, scripts
4. **CI/CD** — GitHub Actions for automated deploy (optional, can be manual initially)
