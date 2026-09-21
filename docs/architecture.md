# Architecture

## Layers

```
┌─────────────────────────────┐
│ App/            (app shell) │  @main, WindowGroup — wiring only
├─────────────────────────────┤
│ MyAppUI         (SwiftUI)   │  thin views, no business logic
├─────────────────────────────┤
│ MyAppCore       (logic)     │  models + view models, no SwiftUI/AppKit/
│                             │  UIKit/Cocoa import — enforced by lint and
│                             │  test; 80% line-coverage floor
└─────────────────────────────┘
```

The dependency direction is strictly one-way: `MyAppCore` ← `MyAppUI` ← `App`.

`MyAppCore` must stay free of UI frameworks so it also serves an iOS target
(`docs/adding-ios.md`). SwiftPM's target graph cannot stop `import SwiftUI` — a system
framework is not a package dependency — so the boundary is enforced twice, by text
match: `.swiftlint.yml`'s `no_ui_import_in_core` custom rule (the pre-commit hook,
`just lint`, CI's `lint` job) and the `ArchitectureBoundaryTests` suite in
`MyAppCoreTests` (`just test`, CI's `test` job). Both reject `SwiftUI`, `AppKit`,
`UIKit`, and `Cocoa` (which re-exports AppKit), including attributed
(`@preconcurrency import AppKit`) and kind-qualified (`import struct SwiftUI.Color`)
imports. A `//`-commented import is ignored, but one that starts a line inside a
`/* … */` block or a multi-line string literal is still flagged — delete it instead.
"Platform-agnostic" here means free of UI frameworks, not buildable on Linux:
Apple-only frameworks such as Combine stay allowed.

## Where new code goes

| You are adding… | It goes in… | Tested by… |
|---|---|---|
| Domain logic, state, view models | `Packages/MyAppKit/Sources/MyAppCore` | Swift Testing in `Tests/MyAppCoreTests` (coverage-gated) |
| Views, view modifiers | `Packages/MyAppKit/Sources/MyAppUI` | Core view-model tests + the launch UI test |
| App lifecycle, scenes, menus | `App/` | `LaunchUITests` + `just smoke` |

Keeping logic out of views is what makes the coverage floor honest: the gate
measures the code that can regress silently, not SwiftUI layout.

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
