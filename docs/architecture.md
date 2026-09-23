# Architecture

## Layers

```
┌───────────────────────────────────────────────────┐
│ App/                                  (app shell) │  @main, WindowGroup — wiring
│                                                   │  only; composition root
├─────────────────────────┬─────────────────────────┤
│ HintjumpUI     (SwiftUI)   │ HintjumpPlatform     (OS)  │  siblings — neither one
│ thin views, no business │ adapters behind Core    │  imports the other
│ logic                   │ ports; AppKit and co.   │
├─────────────────────────┴─────────────────────────┤
│ HintjumpCore                                 (logic) │  models, view models, ports;
│                                                   │  no UI/OS-framework import —
│                                                   │  enforced by lint and test;
│                                                   │  80% line-coverage floor
└───────────────────────────────────────────────────┘
```

The dependency direction is strictly one-way: `HintjumpCore` ← `HintjumpUI` and
`HintjumpCore` ← `HintjumpPlatform`, and both ← `App`.

`HintjumpCore` must stay free of UI frameworks so it also serves an iOS target
(`docs/adding-ios.md`). SwiftPM's target graph cannot stop `import SwiftUI` — a system
framework is not a package dependency — so the boundary is enforced twice, by text
match: `.swiftlint.yml`'s `no_ui_import_in_core` custom rule (the pre-commit hook,
`just lint`, CI's `lint` job) and the `ArchitectureBoundaryTests` suite in
`HintjumpCoreTests` (`just test`, CI's `test` job). Both reject the UI frameworks
`SwiftUI`, `AppKit`, `UIKit`, and `Cocoa` (which re-exports AppKit), and the
OS-integration frameworks an adapter reaches for first — `ApplicationServices`
(accessibility), `Carbon` (hotkeys), and `ServiceManagement` (login items) — including
attributed
(`@preconcurrency import AppKit`) and kind-qualified (`import struct SwiftUI.Color`)
imports. A `//`-commented import is ignored, but one that starts a line inside a
`/* … */` block or a multi-line string literal is still flagged — delete it instead.
"Platform-agnostic" here means free of those frameworks, not buildable on Linux:
Apple-only frameworks such as Combine stay allowed, and so does Foundation — and so do
`os` and `OSLog`, deliberately, so Core can log (see Logging below).

## Ports and adapters

Code that talks to the OS — `NSWorkspace`, accessibility, a Carbon hotkey, an event tap,
an `NSPanel` overlay, a login item — lives in `HintjumpPlatform`, never in Core, a view, or
the shell. It is always the same four pieces, and the template ships one worked example
of them to copy:

1. **The port**, in Core — a `Sendable` protocol taking and returning value types Core
   owns: `FrontmostAppProviding` in
   `Packages/HintjumpKit/Sources/HintjumpCore/FrontmostAppProviding.swift`.
2. **The adapter**, in Platform — the OS framework import, translating the OS type into
   the Core value and doing nothing else: `WorkspaceFrontmostAppProvider` in
   `Packages/HintjumpKit/Sources/HintjumpPlatform/WorkspaceFrontmostAppProvider.swift`.
3. **The fake**, in the test target — a real implementation answering from data the test
   hands it, used by the Core tests of whatever consumes the port
   (`.claude/rules/testing.md` › Fakes, not mocks): `FakeFrontmostAppProvider` in
   `Packages/HintjumpKit/Tests/HintjumpCoreTests/FrontmostAppViewModelTests.swift`.
4. **The local-machine test**, in `Packages/HintjumpKit/Tests/HintjumpPlatformTests` — the
   adapter against the *real* OS, which the fake by construction cannot check:
   `WorkspaceFrontmostAppProviderTests` asks the live `NSWorkspace`. Every suite there
   carries the `.requiresLocalMachine` trait, so it runs only with
   `RUN_LOCAL_MACHINE_TESTS=1` — what `just test-local` sets — and is reported as
   *skipped* under `just test` and in CI. It has to be: a runner has no logged-in GUI
   session and cannot be granted Accessibility, Input Monitoring, or Screen Recording,
   so such a test could only ever fail there. A skip is the honest outcome, and a human
   runs `just test-local` when an adapter changes and puts the output in the pull
   request (`.claude/rules/testing.md` › Where a Test Goes). Those tests act only on what
   they own — events posted to the test process itself, a window that never becomes key —
   so the run needs no hands off the Mac.

`App/` is the composition root: the only place that constructs an adapter and hands it
to a Core view model, so nothing below it knows which implementation answered. A test
substitutes the fake at that same seam.

`HintjumpPlatform` is deliberately **outside the coverage floor** — `scripts/coverage.sh`
measures `Sources/HintjumpCore` only. That is a constraint on adapters rather than a
licence: an adapter carries translation, so it has no branch worth a test. The moment
one needs a decision, the decision moves into Core behind the port, where the floor
sees it. What the floor cannot hold is the translation itself — whether the OS really
answers what the adapter assumes — and that is what the fourth piece is for.

## Logging

**`HintjumpCore` imports `os` directly, and that does not break the boundary.** The ban
list above is UI frameworks and the OS-integration frameworks an adapter reaches for;
`os` is neither. It pulls in no AppKit, it is available on every Apple platform Core is
meant to serve (`docs/adding-ios.md`), and it writes to the unified log rather than
touching the screen or the OS on Core's behalf. So logging is *not* modelled as a port:
a `LoggingPort` would buy no testability — a log line is not an outcome a test asserts —
and would cost every Core type an injected dependency it does not otherwise need. `os`
and `OSLog` are therefore absent from both halves of the ban list, `.swiftlint.yml`'s
`no_ui_import_in_core` and `ArchitectureBoundaryTests`, and a test case pins their
absence so narrowing that list later fails loudly.

Every logger lives in `AppLog` (`Packages/HintjumpKit/Sources/HintjumpCore/AppLog.swift`), the
one place the subsystem is spelled. It is a literal — the app's bundle identifier — and
not `Bundle.main.bundleIdentifier`, which answers for the test runner under `swift test`
and for the preview agent inside an Xcode preview; `scripts/bootstrap.sh` rewrites the
literal with the same placeholder replacement that rewrites `project.yml`, and
`AppLogTests` fails if the two disagree. `HintjumpUI`, `HintjumpPlatform`, and `App/` log
through the same loggers, which they already see by importing `HintjumpCore`, so one
`just logs` stream shows the whole app.

The conventions that go with it — one category per concern, a privacy annotation on
anything user-derived, and never `print`/`debugPrint`/`NSLog` under `Sources/` or `App/`
(`.swiftlint.yml`'s `no_print_in_sources` rejects them) — are in
`.claude/rules/swift.md` › Logging. `FrontmostAppViewModel.refresh()` is the worked
example: it logs that a refresh happened `.public` and the other application's name
`.private`.

## Where new code goes

| You are adding… | It goes in… | Tested by… |
|---|---|---|
| Domain logic, state, view models | `Packages/HintjumpKit/Sources/HintjumpCore` | Swift Testing in `Tests/HintjumpCoreTests` (coverage-gated) |
| Views, view modifiers | `Packages/HintjumpKit/Sources/HintjumpUI` | Core view-model tests, off-screen rendering compared with reference images in `Tests/HintjumpUITests` (`just record-snapshots` to re-record), and the launch UI test |
| OS integration: AppKit, accessibility, hotkeys, login items, the file system beyond Foundation | `Packages/HintjumpKit/Sources/HintjumpPlatform`, as an adapter behind a Core port | Core tests through a fake of the port (coverage-gated), plus an opt-in local-machine test of the adapter in `Tests/HintjumpPlatformTests` — `just test-local` |
| App lifecycle, scenes, menus, wiring an adapter to a view model | `App/` | `LaunchUITests` + `just smoke` |

That last row carries one decision the table cannot: the app's *shape*. The template
ships a regular windowed app — `WindowGroup`, a Dock tile, a launch test that waits for
a window. A menu-bar agent (`LSUIElement`, `MenuBarExtra`, a launch test that waits for
a status item) changes `project.yml`, `App/HintjumpApp.swift`, and
`LaunchUITests/LaunchTests.swift`, and nothing below them.
`.agents/skills/starting-an-app/references/app-shapes.md` gives both shapes as proven
code, including where an `NSApplicationDelegateAdaptor`'s delegate lives when
`MenuBarExtra` is not enough (`HintjumpPlatform`, never `App/`).

Keeping logic out of views is what makes the coverage floor honest: the gate
measures the code that can regress silently, not SwiftUI layout. The same reasoning
keeps decisions out of adapters — see "Ports and adapters" above.

## The Settings window

The Settings window (`docs/design/settings-window.md`) is a SwiftUI `Settings` scene,
opened by the status menu's "Settings…" item through `@Environment(\.openSettings)`,
rather than a `Window` scene opened with `openWindow`. macOS 14, the deployment floor,
has both; #103 had to pick the one that meets three needs, and `Settings` meets them all:

- **It opens from the `.menu`-style `MenuBarExtra`.** A menu item is a `Button`, and a
  `Button` can call `openSettings()` like any action. `SettingsLink` would open the
  window too, but runs no code of its own, and the activation below has to run first.
- **It comes to the front from an `LSUIElement` agent.** An agent is never the active
  app while another app is in front, so a window it opens appears behind that app. The
  item calls `NSApplication.shared.activate()` before `openSettings()`, which is why it
  is a `Button` and not a `SettingsLink` (`App/SettingsMenuItem.swift`).
- **It can be opened from code**, which #107's first-launch open needs: `openSettings`
  is an environment value, so any view in the app — the status item's label is always
  there — can call it with the same activation first.

What decided between them is launch. SwiftUI may present an app's first window scene
when the app starts, and the modifier that rules that out for a `Window`,
`.defaultLaunchBehavior(.suppressed)`, is macOS 15: on 14 an agent with a `Window`
scene risks showing its settings on every start, where #107 wants that only on first
launch. A `Settings` scene never opens by itself,
comes with the title and the ⌘, a Mac app's settings have, and is one window however
often it is asked for. The one thing it gives up — an `id` to open by name — nothing
here needs.

The window's state lives in `SettingsViewModel` (`HintjumpCore`), which `App/` builds
once in `AppComposition`, so the selected pane outlives the window and every pane added
later (#104, #105, #106) reads the same store, applier, and gate. A pane is one case of
`SettingsPane`, in sidebar order, and one view in `HintjumpUI`; `SettingsDetail`
switches over the enum, so a new case does not compile until its view exists.

## Recommended optional dependencies

The template ships with zero. When a real need appears, these are vetted
starting points.

### For tests and distribution

- [ViewInspector](https://github.com/nalexn/ViewInspector) — unit-test SwiftUI
  view hierarchies when view-model tests stop being enough.
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
  — pixel/structure regression tests for complex custom views.
- [Sparkle](https://sparkle-project.org/) — in-app updates once you distribute
  outside the App Store and users ask for auto-update (see docs/distribution.md).

### What a utility app reaches for first

Four needs turn up in nearly every hotkey-driven or menu-bar app, and each one's
zero-dependency answer is stated first on purpose. In this layout that answer is an
adapter in `HintjumpPlatform` behind a Core port ("Ports and adapters" above) — usually
less code than integrating a package, and it keeps the decision in Core where the
coverage floor sees it. Reach for a package only when the "worth it when" sentence
describes your app.

Every package named below was checked against `.claude/rules/project.md`'s dependency
checklist on **2026-09-21**: license, latest release, whether the repository is
archived, the `platforms:` floor in its `Package.swift`, and whether that manifest
declares a binary target or a build plugin. Re-check before you add one — these facts
go stale, and the checklist's Need, Weight, and Advisories items are still yours to
answer for your app.

**Global hotkeys.** Carbon's `RegisterEventHotKey` is still the supported API for a
system-wide shortcut, and wrapping it costs roughly sixty lines: an adapter in
`HintjumpPlatform` that installs one `EventHandlerUPP`, keeps an id→handler dictionary,
and hands Core a `Sendable` port. `Carbon` is one of the frameworks Core may not
import, which is why the adapter is the shape rather than a workaround. A package is
worth it when your users rebind shortcuts in the UI — the recorder control, its
conflict detection against system shortcuts, and persistence are the tedious part, not
the registration.

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — passes:
  MIT; 3.1.0 released 2026-09-11; not archived; floor `.macOS(.v10_15)`, at or below
  this package's `.macOS(.v14)`; one Swift target, no binary target, no build plugin,
  no package dependencies. It ships AppKit and SwiftUI recorder views, so it belongs to
  `HintjumpUI` and `HintjumpPlatform` — its types must not reach Core.

**Launch at login.** No package. `SMAppService.mainApp.register()` (ServiceManagement,
macOS 13+, below this package's macOS 14 floor) is the entire API, with
`SMAppService.mainApp.status` to read it back; it lives in a `HintjumpPlatform` adapter
because `ServiceManagement` is also on Core's blocked-import list. Do not add
`sindresorhus/LaunchAtLogin`: that repository now redirects to `LaunchAtLogin-Legacy`
and is archived (last release v5.0.2, 2024-06-25), so it fails the checklist's
Continuity item outright. Its successor,
[LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) (MIT,
v1.1.0 released 2023-12-21, floor `.macOS(.v13)`), is a few lines around that same
call and fails the Need item instead — Foundation and one system framework already do
the job.

**A human-editable config file.** `Codable` plus `JSONEncoder`/`JSONDecoder` from
Foundation covers it: set `outputFormatting` to `[.prettyPrinted, .sortedKeys]` so the
file diffs cleanly, decode into a Core value type, and let a `HintjumpPlatform` adapter
own the path under `~/Library/Application Support`. A package is worth it when the file
is a contract with the user rather than an implementation detail — when they are
expected to edit it by hand and want comments and trailing commas, which JSON has
neither of. That format is TOML.

- [TOMLDecoder](https://github.com/dduan/TOMLDecoder) — passes: MIT; 0.4.5 released
  2026-07-11; not archived; floor `.macOS(.v10_15)`; a pure-Swift library target with
  no binary target, and no package dependency in the default configuration (its
  benchmark, docs, and formatting dependencies sit behind `TOMLDECODER_*` environment
  opt-ins). It decodes only — rendering the file back out is yours to write, which
  usually fits, since the app writes a commented default once and the user owns it
  afterwards.
- [TOMLKit](https://github.com/LebJe/TOMLKit) reads *and* writes, but did not pass as
  checked: its manifest appends `apple/swift-docc-plugin` unconditionally, and a build
  plugin is build-time code the checklist routes to explicit human approval. Its latest
  release, 0.6.0, is also from 2024-01-03, with the last commit 2025-01-18. It wraps
  the toml++ C++ sources in a `CTOML` source target — that is not a binary target, so
  that item is fine; the build plugin and the release age are what stop it.

**Settings window.** Nothing is vetted here, and that is the finding rather than a gap
to fill later. SwiftUI's `Settings` scene (macOS 11+) already gives the ⌘, item, the
standard window, and its own scene phase; put a `TabView` in it, keep the state in a
Core view model, and persist it through a port exactly as above.
[Settings](https://github.com/sindresorhus/Settings) was checked and would pass on
license and shape (MIT, floor `.macOS(.v10_13)`, one resource-bearing target, no binary
target or build plugin), but its latest release, 3.1.1, is from 2024-05-07, and what it
buys is a toolbar-tab preferences window that the `Settings` scene now gives for free.
Add it only if you need that exact pre-Ventura look.

Before adding any dependency, apply the checklist in `.claude/rules/project.md`
(maintenance, license, transitive weight) and commit `Package.resolved` with it.
