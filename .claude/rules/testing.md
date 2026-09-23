---
paths:
  - "Packages/**/Tests/**"
  - "LaunchUITests/**"
---

## Where a Test Goes

Three kinds of test, split by what is under test:

- **A decision → a Core test with a fake.** Anything that branches, clamps, formats, or
  remembers lives in `HintjumpCore` and is tested in `Tests/HintjumpCoreTests` against a fake
  of the port (see "Fakes, not mocks" below). These run in CI on every push and are what
  the 80% line-coverage floor measures. This is the default: if an adapter looks like it
  needs a test for a decision, move the decision into Core instead.
- **Translation to or from the OS → a local-machine test.** Whether `NSWorkspace`, an
  event tap, or the accessibility API really answers what the adapter assumes can only
  be checked against the real OS. Those tests live in `Tests/HintjumpPlatformTests`, every
  suite carries the `.requiresLocalMachine` trait, and a human runs them with
  `just test-local`. CI cannot: a runner has no logged-in GUI session and cannot be
  granted Accessibility, Input Monitoring, or Screen Recording. So they are reported as
  **skipped** on every other run rather than quietly absent, and a pull request that
  changes an adapter pastes its `just test-local` output as the evidence no gate can
  produce.
- **What a view draws → a rendering test.** A view in `HintjumpUI` holds no decision, but
  how it draws Core's state — colours, type, spacing — can still regress.
  `Tests/HintjumpUITests` renders it off screen with SwiftUI's `ImageRenderer` (no window,
  no display, no TCC grant, so it runs under `just test` and in CI) and compares it pixel
  by pixel with a committed PNG under `References/`. A view made of AppKit-backed
  controls — a grouped `Form`, a `Link` — which `ImageRenderer` draws as a placeholder,
  is drawn by an `NSHostingView` into a fixed-size sRGB bitmap instead, still with no
  window (`SettingsRenderingTests`). An intended change is re-recorded
  with `just record-snapshots`, and the new PNG files are reviewed in the pull request. The
  state a scene renders is built the way Core builds it (`HintLayout`), so the image is
  the product's own layout, not a hand-placed copy.

The first default is also what keeps the developer's Mac out of verification: a behavior
that only the running app can show today is a candidate for moving its decision into
Core, so a unit test sees it instead (`AGENTS.md` › How far verification goes).

A local-machine test acts only on what it owns, so it runs while the developer keeps
working and nothing they do changes its result: it posts events to its own process
(`CGEventClickPerformer`'s internal `.process` delivery), never at the HID level; a
window it shows never becomes key; and a key event is handed to the window directly
rather than typed. What only real global input can show — the pointer moving, a click
routed to the window under it, a panel taking key focus — is left to the last rung of
`AGENTS.md`'s "How far verification goes", the developer's Mac, announced first.

A local-machine test never becomes the only test of a decision: it is human-run, so it
proves nothing about the pull request nobody ran it for. Adapters stay translation-only,
and outside the coverage floor, precisely so that stays true. When macOS withholds an
answer for lack of a grant it reports nothing rather than an error, so unwrap through
`LocalMachineTests.require(_:requires:)` — its failure names the grant instead of
reading as a broken adapter.

## Framework and Structure

- Swift Testing only (`@Test`, `#expect`, `#require`, `@Suite`); XCTest is reserved for the
  XCUITest launch target in `LaunchUITests/`
- Use `@Test(arguments:)` for input/output variations; don't copy-paste test bodies
- Group related tests in a `@Suite`; annotate `@MainActor` suites that touch view models
- TDD is required: write the failing test first, then implement to green

## What to Test

- Test *behavior and contracts*, not implementation details
- Always test the happy path AND the error path for every public API
- Error-path tests assert the thrown error's payload with `#expect(throws:)`, not just its type

## Fakes, not mocks

A port declared in `HintjumpCore` (a `Sendable` protocol whose adapter lives in
`HintjumpPlatform`) is substituted in tests by a **fake**, never a mock. A fake is a real,
working implementation of the protocol that lives in the test target, answers from data
the test hands it, and records what it was asked in a plain value — a call count, or the
arguments it received — which the test reads afterwards with `#expect`. It declares no
expectations up front, verifies nothing itself, and needs no framework:
`FakeFrontmostAppProvider` in `FrontmostAppViewModelTests.swift` is the worked example to
copy. Every Core test of a given port uses that one fake, so the port's test-time
behavior is defined in one place rather than re-stubbed per test. Asserting on the
recorded calls is for the cases where *asking* is the behavior (asking again on each
refresh, not asking at all during `init`); otherwise assert on the state the answer
produced, not on the interaction that produced it.

## Edge Cases (always consider these)

- **Boundary values**: values at, just inside, and just outside every bound
- **Repeated operations**: idempotence at bounds (clamp twice, reset twice)
- **State transitions**: initial state, after one operation, after error recovery
- **Both branches** of every conditional in Core (the coverage floor will notice if you don't)

## Hygiene

- Tests are independent: no shared mutable state, no ordering assumptions
- No `sleep`/timing-based assertions in unit tests; that flakiness belongs to no one
- NEVER weaken an assertion to make a test pass — fix the code
