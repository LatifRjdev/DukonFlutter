---
description: Testing conventions across all modules
globs: "**/*Test.kt,**/*Tests.swift,**/*.spec.ts"
---

# Testing Rules

- Shared KMP: unit tests for every UseCase and Repository in commonTest
- Use fakes/test doubles, not mocks — test behavior, not implementation
- Android: UI tests with Compose testing library for critical flows (POS checkout, product add)
- iOS: XCTest + SwiftUI previews for visual testing
- Backend: existing Jest tests in api/ — maintain coverage
- Test naming: `should {expected behavior} when {condition}`
- Offline scenarios must be tested: sync queue, conflict resolution, retry
- Integration tests hit real SQLDelight in-memory DB, not mocks
- Each test is independent — no shared mutable state between tests
