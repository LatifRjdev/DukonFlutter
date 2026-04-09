---
description: Review recent changes for quality, bugs, and conventions
---

Review my recent changes. Check:

1. **Architecture**: Does the code follow Clean Architecture boundaries? Is shared code in the right layer?
2. **KMP correctness**: No platform-specific imports in commonMain? expect/actual used correctly?
3. **UI**: Stateless composables/views? State properly hoisted? Previews present?
4. **Offline-first**: Do writes go to local DB first? Is sync queue updated?
5. **Security**: No tokens logged? Secure storage used? Input validated?
6. **Error handling**: Result types used? Edge cases covered?
7. **Testing**: Are new use cases/repositories tested?
8. **Naming**: Follows Kotlin/Swift conventions? Consistent with existing code?
9. **Localization**: All user-facing strings externalized for ru, tg, uz?

Use `git diff` to see staged/unstaged changes and review them.
