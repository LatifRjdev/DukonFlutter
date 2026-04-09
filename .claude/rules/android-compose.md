---
description: Rules for Android Jetpack Compose UI code
globs: "androidApp/**/*.kt"
---

# Android Compose Conventions

- Composables are stateless — all state hoisted to ViewModel
- ViewModels extend AndroidX ViewModel, expose StateFlow
- ViewModels call shared KMP UseCases, not repositories directly
- Navigation via Compose Navigation with type-safe routes
- Use Material 3 components and theme tokens
- Preview functions annotated with @Preview for every screen
- No business logic in Composables — only UI rendering
- Use `collectAsStateWithLifecycle()` for Flow collection
- Screens organized by feature: ui/auth/, ui/pos/, ui/products/, etc.
- Shared components in ui/components/
- String resources in res/values/strings.xml (ru, tg, uz)
