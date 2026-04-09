---
description: Create a new screen on both Android (Compose) and iOS (SwiftUI) from design
---

Create screen: $ARGUMENTS

Steps:
1. Find the matching design in `/design/` directory — look at the PNG and HTML
2. Create the Compose screen in `androidApp/src/main/java/.../ui/{feature}/`
   - Stateless composable with state parameter
   - @Preview function
   - Wire to ViewModel
   - Add to navigation graph
3. Create the SwiftUI view in `iosApp/Sources/UI/{Feature}/`
   - View struct with @ObservedObject ViewModel
   - Preview provider
   - Add to navigation
4. Both screens should call the same shared KMP ViewModel/UseCase
5. Match the design as closely as possible — colors, spacing, typography
6. Add all user-facing strings to localization files
