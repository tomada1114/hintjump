---
paths:
  - "Packages/**/*.swift"
  - "App/**/*.swift"
---

## Design

- Keep modules under 300 lines; one logical concern per file
- Keep functions under 40 lines; prefer 3 or fewer parameters (group related params in a struct)
- Value types first: reach for `struct`/`enum`; use `class` only for identity or reference semantics
- `MyAppCore` must never import SwiftUI, AppKit, UIKit, or Cocoa — it stays platform-agnostic
  (enforced by `.swiftlint.yml`'s `no_ui_import_in_core` and `ArchitectureBoundaryTests`)
- Views in `MyAppUI` stay thin: no business logic, delegate everything to Core view models
- `///` doc comments on all public API; document *why*, not what the signature already says

## Error Handling

- Define typed errors per module (an `enum ... : Error, Equatable` with payload), thrown with context
- NEVER `try!` or force-unwrap (`!`) in production code; `guard let`/`throws` instead
- Never swallow errors silently; if catching, handle meaningfully or rethrow
- Never use errors for control flow

## Concurrency

- Swift 6 language mode is on: data-race safety errors are non-negotiable
- UI-facing state is `@MainActor`; keep Core types `Sendable` where they cross actors
- No `@unchecked Sendable` without a comment proving the invariant it papers over
