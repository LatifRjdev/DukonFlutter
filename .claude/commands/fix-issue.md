---
description: Find and fix a bug based on description
---

Bug report: $ARGUMENTS

Steps:
1. Understand the bug — which feature area is affected?
2. Search for relevant code across shared/, androidApp/, iosApp/, and api/
3. Identify the root cause
4. Implement the fix in the appropriate layer:
   - If business logic bug → fix in shared/ KMP module
   - If UI-only bug → fix in platform-specific code
   - If API bug → fix in api/
5. Verify the fix doesn't break other functionality
6. Run relevant tests: `./gradlew :shared:allTests`
7. Explain what caused the bug and how the fix works
