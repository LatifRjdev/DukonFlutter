# Bug Fixes Design — Manual API Testing Round 1

**Date:** 2026-07-15  
**Scope:** 5 bugs found during 128-feature manual API test run  
**Stack:** NestJS + Prisma (API), Flutter + BLoC (mobile)

---

## B1 — DELETE /stores/:storeId — Missing Route (Soft Delete)

### Problem

`DELETE /stores/:storeId` does not exist. The Flutter client already calls it
(`store_remote_datasource.dart:91`). Returns 404 instead of deleting.

### Decision

**Soft delete** — set `isActive = false`, consistent with Product and Staff patterns
already in the codebase. No hard deletes; data is preserved for auditing.

### Design

**`api/src/modules/stores/stores.service.ts`** — add `softDelete(storeId: string)`:

```ts
async softDelete(storeId: string) {
  return this.prisma.store.update({
    where: { id: storeId },
    data: { isActive: false },
  });
}
```

Returns the updated store object (consistent with other service methods).

**`api/src/modules/stores/stores.controller.ts`** — add `@Delete(':storeId')` handler after
the existing `@Put(':storeId')`:

```ts
@Delete(':storeId')
@UseGuards(JwtAuthGuard, StoreAccessGuard)
remove(@Param('storeId') storeId: string) {
  return this.storesService.softDelete(storeId);
}
```

**Response:** updated store with `isActive: false`  
**HTTP status:** 200 (default)  
**Guards:** same as `@Put(':storeId')` — `JwtAuthGuard` + `StoreAccessGuard`

### Testing

Jest test in `stores.service.spec.ts`:
- `should set isActive to false when softDelete is called`
- Mock `prisma.store.update`, assert called with `{ data: { isActive: false } }`

---

## B2 — Import Preview 500 on Empty File → 400

### Problem

`POST /stores/:storeId/products/import/preview` returns 500 when the uploaded file
is empty (zero bytes). The `parseFile` method calls `workbook.xlsx.load(buffer)`
without checking for an empty buffer — ExcelJS throws, NestJS catches as 500.

### Design

**`api/src/modules/products/import-products.service.ts`** — add guard at the start of
`parseFile(buffer: Buffer)`:

```ts
private async parseFile(buffer: Buffer) {
  if (!buffer || buffer.length === 0) {
    throw new BadRequestException('Файл пустой или повреждён');
  }
  // existing code continues...
}
```

`BadRequestException` → 400 with the message string. No other changes needed;
`preview()` and `import()` both call `parseFile`, so both are fixed by this one guard.

### Testing

Jest test in `import-products.service.spec.ts`:
- `should throw BadRequestException when buffer is empty`
- `should throw BadRequestException when buffer is null`
- Pass `Buffer.alloc(0)` and `null` to `parseFile`, expect `BadRequestException`

---

## B3 — GET /stores/:storeId/notifications/settings — Missing Route

### Problem

`PUT /stores/:storeId/notifications/settings` exists but `GET` on the same path
does not. The Flutter settings page (`notification_settings_page.dart:36`) calls
`GET /stores/${storeId}/notifications/settings` on load, so the page always fails
to populate.

### Design

**`api/src/modules/notifications/notifications.service.ts`** — add
`getNotificationSettings(storeId: string)`:

```ts
async getNotificationSettings(storeId: string) {
  const store = await this.prisma.store.findUnique({
    where: { id: storeId },
    select: { settings: true },
  });
  const notif = (store?.settings as any)?.notifications ?? {};
  return {
    lowStockAlerts:         notif.lowStockAlerts         ?? true,
    newSaleAlerts:          notif.newSaleAlerts           ?? true,
    shiftClosedAlerts:      notif.shiftClosedAlerts       ?? true,
    deliveryCompletedAlerts: notif.deliveryCompletedAlerts ?? true,
    debtReminderAlerts:     notif.debtReminderAlerts      ?? true,
  };
}
```

Defaults all fields to `true` so new stores get full alerts without an explicit
settings write first.

**`api/src/modules/notifications/notifications.controller.ts`** — add
`@Get('stores/:storeId/notifications/settings')` **before** the existing
`@Put('stores/:storeId/notifications/settings')` to avoid NestJS route-matching
ambiguity (static `settings` segment must be matched before `/:id` wildcard):

```ts
@Get('stores/:storeId/notifications/settings')
@UseGuards(JwtAuthGuard, StoreAccessGuard)
getSettings(@Param('storeId') storeId: string) {
  return this.notificationsService.getNotificationSettings(storeId);
}
```

**Response shape:** flat object matching `NotificationSettingsDto` fields.

### Testing

Jest test in `notifications.service.spec.ts`:
- `should return all-true defaults when store has no notification settings`
- `should return saved values when notification settings exist`
- Mock `prisma.store.findUnique` with `{ settings: null }` and with a populated
  `settings.notifications` object

---

## B4 — zakatDue Server-Side Validation Too Strict

### Problem

`POST /stores/:storeId/zakat/calculate` rejects requests where the client sends a
`zakatDue` that differs from the server-computed value by more than 0.5%. Because
the server always stores `serverZakatDue` anyway (line 267 of `zakat.service.ts`),
the validation has no functional purpose and blocks legitimate requests (e.g. when
`serverZakatDue = 0`, any non-zero client value fails absolutely).

### Decision

**Remove the validation entirely.** The server is the source of truth for `zakatDue`
and always overwrites the client value. The DTO field `zakatDue` is kept optional
(already is) for backwards compatibility with clients that send it.

### Design

**`api/src/modules/zakat/zakat.service.ts`** — remove:

1. The `ZAKAT_DUE_TOLERANCE` constant.
2. The entire comparison block (~lines 239–261) that computes `clientZakatDue`,
   computes `tolerance`, and throws `BadRequestException`.

Everything else stays as-is. `serverZakatDue` is still computed and stored.

### Testing

Jest test in `zakat.service.spec.ts`:
- `should accept request when client sends zakatDue=0 and server computes nonzero`
- `should accept request when client sends zakatDue=100 and server computes 0`
- `should not throw when zakatDue field is omitted`

---

## B5 — receipt-template Response Wrapped in Nested Key

### Problem

`GET /stores/:storeId/receipt-template` and `PUT /stores/:storeId/receipt-template`
return `{ receiptTemplate: { ... } }` instead of the flat template object. The
Flutter client and API consumers expect the fields directly at the top level.

### Design

**`api/src/modules/stores/stores.service.ts`** — flatten the return values:

`getReceiptTemplate()` (line ~128) — change:
```ts
// before
return { receiptTemplate: template };
// after
return template;
```

`updateReceiptTemplate()` (line ~153) — change:
```ts
// before
return { receiptTemplate: { ...template, ...dto } };
// after
return { ...template, ...dto };
```

No controller changes needed. The controller passes through whatever the service
returns.

### Testing

Jest tests in `stores.service.spec.ts`:
- `should return flat template object from getReceiptTemplate`
- `should return flat merged object from updateReceiptTemplate`
- Assert the returned object does **not** have a `receiptTemplate` key

---

## Summary

| ID | Route / Location | Fix |
|----|-----------------|-----|
| B1 | `DELETE /stores/:storeId` | Add soft-delete route + service method |
| B2 | `import-products.service.ts` `parseFile()` | Guard: empty buffer → 400 |
| B3 | `GET /stores/:storeId/notifications/settings` | Add GET route + service method |
| B4 | `zakat.service.ts` validation block | Remove entire zakatDue comparison |
| B5 | `stores.service.ts` receipt-template | Return flat object, remove wrapper key |
