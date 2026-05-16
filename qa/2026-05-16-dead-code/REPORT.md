# Dead-code sweep — 2026-05-16 (Spec F D.1)

## Method
`ts-prune --project tsconfig.json` on api/, `dart_code_metrics check-unused-code lib` on app/. Triple-grep across `src/` + `test/` + module/decorator-array references for every candidate; KEEP applied conservatively. Delete bar matches the `stock-movements.controller.ts` precedent from Spec E.

## Summary
- 20 backend candidates / 20 DELETE / 0 KEEP
- 42 Flutter candidates / 13 DELETE / 29 KEEP (dcm doesn't scan `test/` — all 29 KEEPs verified via grep in test files)
- 33 total deletions across 6 commits
- Tests held: 226 unit / 11 e2e / 441 flutter, 0 tsc, 0 dart issues throughout
- `npx ts-prune` clean on second pass

## Backend findings (api/)

| Symbol | File | Disposition | Reason |
|--------|------|-------------|--------|
| `default` (registerAs 'app') | `api/src/config/app.config.ts` | DELETE | Never loaded into `ConfigModule.forRoot({ load: [...] })`; file never imported |
| `default` (registerAs 'database') | `api/src/config/database.config.ts` | DELETE | same |
| `default` (registerAs 'jwt') | `api/src/config/jwt.config.ts` | DELETE | same |
| `default` (registerAs 'redis') | `api/src/config/redis.config.ts` | DELETE | same |
| `default` (registerAs 'throttle') | `api/src/config/throttle.config.ts` | DELETE | same |
| `ApiPaginatedResponse` | `api/src/common/decorators/api-paginated-response.decorator.ts` | DELETE | Swagger helper never applied |
| `RequiresPlan` | `api/src/common/decorators/requires-plan.decorator.ts` | DELETE | Replaced by `@RequiresFeature`; only stale comments in `subscription.guard.spec.ts` |
| `Roles` (+ `ROLES_KEY`) | `api/src/common/decorators/roles.decorator.ts` | DELETE | `@Roles` never applied; `ROLES_KEY` consumed only by the dead `RolesGuard` |
| `RolesGuard` | `api/src/common/guards/roles.guard.ts` | DELETE | Never registered as APP_GUARD or used via `@UseGuards`; authorization runs through `PermissionsGuard`/`permissions-matrix.ts` |
| `PaginationQueryDto` | `api/src/common/dto/pagination-query.dto.ts` | DELETE | No controller imports it |
| `PaginatedResponseDto` | `api/src/common/dto/paginated-response.dto.ts` | DELETE | Generic wrapper, zero importers |
| `JwtPayload` | `api/src/common/interfaces/jwt-payload.interface.ts` | DELETE | Never imported |
| `JwtRefreshPayload` | `api/src/common/interfaces/jwt-payload.interface.ts` | DELETE | Never imported |
| `RequestWithUser` | `api/src/common/interfaces/request-with-user.interface.ts` | DELETE | Never imported |
| `ValidationPipe` re-export | `api/src/common/pipes/validation.pipe.ts` | DELETE | One-line re-export of `@nestjs/common`; `main.ts` uses `RuValidationPipe` |
| `AuthResponseDto` | `api/src/modules/auth/dto/auth-response.dto.ts` | DELETE | Auth controller returns inline types |
| `CustomerResponseDto` | `api/src/modules/customers/dto/customer-response.dto.ts` | DELETE | Customer controller returns inline types |
| `CustomerDebtsSummaryDto` | `api/src/modules/customers/dto/debts-summary.dto.ts` | DELETE | Debts endpoint returns inline shape |
| `ImportProductsDto` | `api/src/modules/products/dto/import-products.dto.ts` | DELETE | Excel import uses multipart, not this DTO shape |
| `ProductResponseDto` | `api/src/modules/products/dto/product-response.dto.ts` | DELETE | Products controller returns inline types |
| `SupplierResponseDto` | `api/src/modules/suppliers/dto/supplier-response.dto.ts` | DELETE | Suppliers controller returns inline types |

3 directories also pruned (now empty): `api/src/config/`, `api/src/common/interfaces/`, `api/src/common/dto/`.

## Flutter findings (app/lib/)

### DELETE (13 symbols across 8 files)

| Symbol | File | Reason |
|--------|------|--------|
| `SalePaymentType` | `app/lib/core/constants/enums.dart` | 0 refs anywhere |
| `SaleStatus` | `app/lib/core/constants/enums.dart` | 0 refs anywhere |
| `DiscountType` | `app/lib/core/constants/enums.dart` | 0 refs anywhere |
| `MovementType` | `app/lib/core/constants/enums.dart` | 0 refs anywhere |
| `StaffRole` | `app/lib/core/constants/enums.dart` | 0 refs anywhere |
| `SyncStatus` (constants copy) | `app/lib/core/constants/enums.dart` | Shadowed by the live `SyncStatus` in `lib/data/sync/sync_engine.dart` with different values — bug-magnet |
| `Failure` + `ServerFailure` + `CacheFailure` + `NetworkFailure` + `ValidationFailure` + `AuthFailure` | `app/lib/core/errors/failures.dart` | Whole file deleted; app uses `AppException` subclasses from `core/errors/exceptions.dart`; bloc `AuthFailure` in `presentation/blocs/auth/auth_state.dart` is a different live class |
| `StringExtensions` + `DateTimeExtensions` + `ContextExtensions` + `NumExtensions` | `app/lib/core/utils/extensions.dart` | Whole file — 0 importers |
| `Validators` | `app/lib/core/utils/validators.dart` | Whole file — 0 importers |
| `DebtPayment` | `app/lib/domain/entities/debt_payment.dart` | Whole file — entity never constructed |
| `SupplierPayment` | `app/lib/domain/entities/supplier_payment.dart` | Whole file — entity never constructed |
| `PlanGate` | `app/lib/presentation/widgets/common/plan_gate.dart` | Widget never mounted; subscription gating runs through `SubscriptionGuard` interceptor |
| `SubscriptionBanner` | `app/lib/presentation/widgets/common/subscription_banner.dart` | Widget never rendered |

### KEEP (29 — dcm doesn't scan test/, all verified via grep)

- `contrastRatio` — used by 11 WCAG assertions in `test/core/theme/theme_contrast_test.dart`
- 21 public widgets each exercised by a `*_golden_test.dart` (and `AppBottomSheet`/`AppDialog` also by `*_chrome_test.dart`): `AppBottomSheet`, `AppDialog`, `OtpInput`, `QuantitySelector`, `StepIndicator`, `QuickActionCard`, `SaleListItem`, `StatCard`, `PeriodSelector`, `ProfitSummaryCard`, `StatSummaryRow`, `OnboardingSlide`, `CartItemWidget`, `PaymentMethodTile`, `QuickProductChip`, `ProductCard`, `ProductListItem`, `SettingsTile`, `CurrentShiftCard`, `StaffCard`, `ZakatBreakdownCard`
- `SyncStatus` (live copy in `lib/data/sync/sync_engine.dart`) and `AuthFailure` (live bloc state) — dcm flagged collateral damage from the shadow deletes; both have abundant prod + test refs

## Commits (newest first)

- `505f884` — remove 7 unused Flutter source files
- `eb636ba` — drop 6 unused enums from `app/lib/core/constants/enums.dart`
- `9e78659` — remove unused `PaginatedResponseDto` (2nd ts-prune pass)
- `79ec5d8` — remove unused module response DTOs (6 files)
- `34720b9` — remove unused `common/*` helpers (8 files)
- `7515de3` — remove unused `src/config/*` registerAs files (5 files)
