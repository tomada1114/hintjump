# Project Guide

## Overview

This is a macOS SwiftUI app built from a strict template: XcodeGen generates the
Xcode project from `project.yml`, all real code lives in a local Swift package
(`Packages/MyAppKit`), and quality gates (SwiftLint strict, SwiftFormat, Swift 6
language mode, an 80% line-coverage floor on the Core module) are enforced from
day one.

## Quick Reference

```bash
just install   # Install pinned tools (mise), git hooks, and generate the Xcode project
just generate  # Regenerate MyApp.xcodeproj from project.yml
just fmt       # Format code (swiftformat)
just lint      # Lint (swiftformat --lint + swiftlint --strict + shellcheck + actionlint)
just test      # Run tests with the 80% coverage floor on MyAppCore
just build     # Build the app (Debug)
just run       # Build (Debug) and launch the app, left running until you quit it
just uitest    # Run the XCUITest launch test
just smoke     # Build Release and assert the app launches
just check     # Run all checks: fmt → lint → test → build
just clean     # Remove build artifacts and the generated project
```

Without Just: run the underlying commands listed in each `justfile` recipe
(see CONTRIBUTING.md).

## Architecture

```
App/                        # Thin shell: @main entry point + resources, NO logic
Packages/MyAppKit/
├── Sources/MyAppCore/      # Domain logic + view models — platform-agnostic, no SwiftUI,
│                           #   coverage-gated at 80%
├── Sources/MyAppUI/        # SwiftUI views — thin, delegate to Core view models
└── Tests/MyAppCoreTests/   # Swift Testing suites
LaunchUITests/              # XCUITest launch guarantee (XCTest by necessity)
```

- New logic goes in `MyAppCore` with tests; views only render Core state
- The dependency direction is one-way: Core ← UI ← App
- `MyApp.xcodeproj` is generated — edit `project.yml` instead

## Review Checklist

Before submitting a PR:

1. `just check` passes (format, lint, tests + coverage, build)
2. New public APIs have `///` doc comments explaining *why*
3. Tests cover the new functionality (happy path AND error path)
4. No new dependencies without justification (see .claude/rules/project.md)
5. User-facing changes have a `CHANGELOG.md` entry under `[Unreleased]`
6. Commits and the PR title follow Conventional Commits (English)

## Important Reminders

- All code, docs, commits, and PRs must be written in English
- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files unless explicitly requested
- NEVER lower the coverage floor or disable safety lint rules to make a check pass
