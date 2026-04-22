# Sprint 7 — AppSnackbar Message L10n

**Goal:** Localize the 30+ hardcoded Russian messages passed into `AppSnackbar.success/error/info(context, 'X')` across the app.

**Architecture:** 2 phases — add `snack*` keys to ru/tg/uz arb, then migrate call-sites.

---

## Sprint 7 Complete — 2026-04-22

**Outcome:** 33 hardcoded Russian AppSnackbar messages migrated to `AppLocalizations.snack*` keys; 7 calls deliberately left as dynamic passthroughs (`state.error`, `state.message`, `e.toString()`) because their message content lives in Bloc/repository layer, not at the call-site.

**Commits:**
- `02776c7` feat(l10n) — 30 new `snack*` keys in ru/tg/uz arb (24 literals + 6 ICU-placeholder methods).
- `57effe8` refactor(l10n) — migrated 33 call-sites across 20 files.

**Key mapping highlights:**
- Shift/POS/receipt: `snackShiftOpened`, `snackShiftClosed`, `snackReceiptPrinted`, `snackReceiptSentToTelegram`, `snackPrintError`, `snackPrinterNotConnected`, `snackTelegramSendFailed`.
- Settings: `snackSettingsSaved`, `snackScannerSettingsSaved`, `snackTemplateSaved`, `snackLanguageSaved`, `snackCacheCleared`.
- Operations: `snackIntakeSuccess`, `snackRefundSuccess`, `snackAdjustmentAdded`, `snackCalculationCopied`, `snackSyncCompleted`.
- Selection: `snackSelectOrder`, `snackSelectCourier`, `snackNoPhoneNumber`, `snackStoreSelected(name)`, `snackCustomerSelectedForSale(name)`.
- Error patterns: `snackPrintErrorDetails(error)`, `snackConnectionError(error)`, `snackSyncError(error)`, `snackGenericError(error)`.

**Acceptance:**
- `flutter analyze lib/` → 0 issues.
- `flutter test` → 363/363 pass (baseline maintained).

**Follow-up:**
- Native-speaker review of tg + uz snack translations (marked best-effort).
- Sources of the 7 skipped dynamic messages (Bloc state/error fields) are not yet localized — would require backend/repository layer work.
