---
paths:
  - "Packages/**/*.swift"
  - "App/**/*.swift"
---

## Design

- Keep modules under 300 lines; one logical concern per file
- Keep functions under 40 lines; prefer 3 or fewer parameters (group related params in a struct)
- Value types first: reach for `struct`/`enum`; use `class` only for identity or reference semantics
- `MyAppCore` must never import SwiftUI, AppKit, UIKit, Cocoa, ApplicationServices, Carbon,
  or ServiceManagement — it stays platform-agnostic (enforced by `.swiftlint.yml`'s
  `no_ui_import_in_core` and `ArchitectureBoundaryTests`)
- OS integration goes in `MyAppPlatform`, as an adapter behind a `Sendable` port Core
  declares: value types in and out, translation only, no branching domain logic (that
  belongs in Core, where the coverage floor sees it)
- Views in `MyAppUI` stay thin: no business logic, delegate everything to Core view models
- `MyAppUI` and `MyAppPlatform` are siblings and never import each other; `App/` is the
  composition root that hands a `MyAppPlatform` adapter to a Core view model
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
