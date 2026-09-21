# Architecture

## Layers

```
┌───────────────────────────────────────────────────┐
│ App/                                  (app shell) │  @main, WindowGroup — wiring
│                                                   │  only; composition root
├─────────────────────────┬─────────────────────────┤
│ MyAppUI     (SwiftUI)   │ MyAppPlatform     (OS)  │  siblings — neither one
│ thin views, no business │ adapters behind Core    │  imports the other
│ logic                   │ ports; AppKit and co.   │
├─────────────────────────┴─────────────────────────┤
│ MyAppCore                                 (logic) │  models, view models, ports;
│                                                   │  no UI/OS-framework import —
│                                                   │  enforced by lint and test;
│                                                   │  80% line-coverage floor
└───────────────────────────────────────────────────┘
```

The dependency direction is strictly one-way: `MyAppCore` ← `MyAppUI` and
`MyAppCore` ← `MyAppPlatform`, and both ← `App`.

`MyAppCore` must stay free of UI frameworks so it also serves an iOS target
(`docs/adding-ios.md`). SwiftPM's target graph cannot stop `import SwiftUI` — a system
framework is not a package dependency — so the boundary is enforced twice, by text
match: `.swiftlint.yml`'s `no_ui_import_in_core` custom rule (the pre-commit hook,
`just lint`, CI's `lint` job) and the `ArchitectureBoundaryTests` suite in
`MyAppCoreTests` (`just test`, CI's `test` job). Both reject the UI frameworks
`SwiftUI`, `AppKit`, `UIKit`, and `Cocoa` (which re-exports AppKit), and the
OS-integration frameworks an adapter reaches for first — `ApplicationServices`
(accessibility), `Carbon` (hotkeys), and `ServiceManagement` (login items) — including
attributed
(`@preconcurrency import AppKit`) and kind-qualified (`import struct SwiftUI.Color`)
imports. A `//`-commented import is ignored, but one that starts a line inside a
`/* … */` block or a multi-line string literal is still flagged — delete it instead.
"Platform-agnostic" here means free of those frameworks, not buildable on Linux:
Apple-only frameworks such as Combine stay allowed, and so does Foundation.

## Ports and adapters

Code that talks to the OS — `NSWorkspace`, accessibility, a Carbon hotkey, an event tap,
an `NSPanel` overlay, a login item — lives in `MyAppPlatform`, never in Core, a view, or
the shell. It is always the same three pieces, and the template ships one worked example
of them to copy:

1. **The port**, in Core — a `Sendable` protocol taking and returning value types Core
   owns: `FrontmostAppProviding` in
   `Packages/MyAppKit/Sources/MyAppCore/FrontmostAppProviding.swift`.
2. **The adapter**, in Platform — the OS framework import, translating the OS type into
   the Core value and doing nothing else: `WorkspaceFrontmostAppProvider` in
   `Packages/MyAppKit/Sources/MyAppPlatform/WorkspaceFrontmostAppProvider.swift`.
3. **The fake**, in the test target — a real implementation answering from data the test
   hands it, used by the Core tests of whatever consumes the port
   (`.claude/rules/testing.md` › Fakes, not mocks): `FakeFrontmostAppProvider` in
   `Packages/MyAppKit/Tests/MyAppCoreTests/FrontmostAppViewModelTests.swift`.

`App/` is the composition root: the only place that constructs an adapter and hands it
to a Core view model, so nothing below it knows which implementation answered. A test
substitutes the fake at that same seam.

`MyAppPlatform` is deliberately **outside the coverage floor** — `scripts/coverage.sh`
measures `Sources/MyAppCore` only. That is a constraint on adapters rather than a
licence: an adapter carries translation, so it has no branch worth a test. The moment
one needs a decision, the decision moves into Core behind the port, where the floor
sees it.

## Where new code goes

| You are adding… | It goes in… | Tested by… |
|---|---|---|
| Domain logic, state, view models | `Packages/MyAppKit/Sources/MyAppCore` | Swift Testing in `Tests/MyAppCoreTests` (coverage-gated) |
| Views, view modifiers | `Packages/MyAppKit/Sources/MyAppUI` | Core view-model tests + the launch UI test |
| OS integration: AppKit, accessibility, hotkeys, login items, the file system beyond Foundation | `Packages/MyAppKit/Sources/MyAppPlatform`, as an adapter behind a Core port | Core tests through a fake of the port (the adapter itself is outside the coverage floor) |
| App lifecycle, scenes, menus, wiring an adapter to a view model | `App/` | `LaunchUITests` + `just smoke` |

Keeping logic out of views is what makes the coverage floor honest: the gate
measures the code that can regress silently, not SwiftUI layout. The same reasoning
keeps decisions out of adapters — see "Ports and adapters" above.

## Recommended optional dependencies

The template ships with zero. When a real need appears, these are vetted
starting points:

- [ViewInspector](https://github.com/nalexn/ViewInspector) — unit-test SwiftUI
  view hierarchies when view-model tests stop being enough.
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
  — pixel/structure regression tests for complex custom views.
- [Sparkle](https://sparkle-project.org/) — in-app updates once you distribute
  outside the App Store and users ask for auto-update (see docs/distribution.md).

Before adding any dependency, apply the checklist in `.claude/rules/project.md`
(maintenance, license, transitive weight) and commit `Package.resolved` with it.
