---
description: Rules for iOS SwiftUI views and architecture
globs: "iosApp/**/*.swift"
---

# iOS SwiftUI Conventions

- Views are thin — logic in ObservableObject ViewModels
- ViewModels wrap shared KMP use cases via Swift-friendly wrappers
- Use @Published properties for state, Combine for reactivity
- NavigationStack with NavigationPath for navigation
- Follow Apple HIG (Human Interface Guidelines)
- Use SF Symbols for icons where appropriate
- Screens organized by feature: UI/Auth/, UI/POS/, UI/Products/, etc.
- Shared components in UI/Components/
- Localization via Localizable.strings (ru, tg, uz)
- Use Swift structured concurrency (async/await) for KMP interop
- Access shared KMP code via generated Swift framework
