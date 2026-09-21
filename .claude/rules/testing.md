---
paths:
  - "Packages/**/Tests/**"
  - "LaunchUITests/**"
---

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

A port declared in `MyAppCore` (a `Sendable` protocol whose adapter lives in
`MyAppPlatform`) is substituted in tests by a **fake**, never a mock. A fake is a real,
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
