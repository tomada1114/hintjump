---
paths:
  - "Packages/**/*.swift"
  - "App/**/*.swift"
---

## Design

- Keep modules under 300 lines; one logical concern per file
- Keep functions under 40 lines; prefer 3 or fewer parameters (group related params in a struct)
- Value types first: reach for `struct`/`enum`; use `class` only for identity or reference semantics
- `HintjumpCore` must never import SwiftUI, AppKit, UIKit, Cocoa, ApplicationServices, Carbon,
  or ServiceManagement — it stays platform-agnostic (enforced by `.swiftlint.yml`'s
  `no_ui_import_in_core` and `ArchitectureBoundaryTests`). `os`/`OSLog` are *not* on that
  list: logging is neither a UI nor an OS-integration framework, so Core imports it
  directly (see Logging below)
- OS integration goes in `HintjumpPlatform`, as an adapter behind a `Sendable` port Core
  declares: value types in and out, translation only, no branching domain logic (that
  belongs in Core, where the coverage floor sees it)
- Views in `HintjumpUI` stay thin: no business logic, delegate everything to Core view models
- `HintjumpUI` and `HintjumpPlatform` are siblings and never import each other; `App/` is the
  composition root that hands a `HintjumpPlatform` adapter to a Core view model
- `///` doc comments on all public API; document *why*, not what the signature already says

## Error Handling

- Define typed errors per module (an `enum ... : Error, Equatable` with payload), thrown with context
- NEVER `try!` or force-unwrap (`!`) in production code; `guard let`/`throws` instead
- Never swallow errors silently; if catching, handle meaningfully or rethrow
- Never use errors for control flow

## Logging

- `os.Logger` is the only logging facility. NEVER `print`, `debugPrint`, or `NSLog`
  anywhere under `Packages/*/Sources/` or `App/`: a `.app` launched the way users launch
  it discards stdout, so those lines are lost exactly when they matter. Enforced by
  `.swiftlint.yml`'s `no_print_in_sources`; test targets are exempt
- Every logger is declared in `AppLog` (`Sources/HintjumpCore/AppLog.swift`), never built
  inline: `subsystem` is the app's bundle identifier, spelled once as a literal there
  (`Bundle.main.bundleIdentifier` answers for the test runner under `swift test` and for
  the preview agent in a preview), and one `category` names one concern. `just logs`
  streams that subsystem; `AppLogTests` fails if it drifts from `project.yml`
- Anything user-derived carries a privacy annotation — another app's name, a window
  title, an accessibility element's label, a file path, anything typed — is `.private`.
  Only values that are safe in anyone's log, such as a state name or a count, are
  `.public`. `os.Logger` defaults interpolated strings to `.private`, so say which one
  you mean rather than relying on the default
- Level by intent: `.debug` for the development stream `just logs` shows, `.info` for a
  milestone worth keeping, `.error`/`.fault` for something that went wrong. See
  `FrontmostAppViewModel.refresh()` for the worked example

## Concurrency

- Swift 6 language mode is on: data-race safety errors are non-negotiable
- UI-facing state is `@MainActor`; keep Core types `Sendable` where they cross actors
- No `@unchecked Sendable` without a comment proving the invariant it papers over
