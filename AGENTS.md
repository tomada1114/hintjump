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
just lint      # Lint (scripts/lint.sh: swiftformat --lint + swiftlint --strict + shellcheck + actionlint + typos)
just test-scripts  # Run the plain-bash tests for scripts/ (scripts/tests/run.sh)
just test      # Run tests with the 80% coverage floor on MyAppCore
just build     # Build the app (Debug)
just run       # Build (Debug) and launch the app, left running until you quit it
just uitest    # Run the XCUITest launch test
just smoke     # Build Release and assert the app launches
just check     # Run all checks: fmt → lint → test-scripts → test → build
just agents-sync   # Regenerate the .claude/skills/ mirror from .agents/skills/
just agents-check  # Fail if .claude/skills/ differs from .agents/skills/
just clean     # Remove build artifacts and the generated project
```

Without Just: run the underlying commands listed in each `justfile` recipe
(see CONTRIBUTING.md).

## Validating a change

Run the narrowest check that can fail, then `just check` before you open a PR.
`just lint` runs `scripts/lint.sh`, the same script the pre-commit hook and CI's lint
job call.

| What you changed | The narrowest check that can fail |
|---|---|
| A Swift file under `Packages/MyAppKit/Sources/MyAppCore/` | `just test` |
| A test under `Packages/MyAppKit/Tests/MyAppCoreTests/` | `just test` |
| A view under `Packages/MyAppKit/Sources/MyAppUI/`, or anything under `App/` | `just build` |
| Formatting or style of any Swift file | `just lint` |
| `project.yml` | `just generate && just build` |
| A test under `LaunchUITests/`, or launch behavior | `just uitest` |
| The Release configuration, or anything only a Release launch shows | `just smoke` |
| A shell script under `scripts/`, or `.githooks/pre-commit` | `just lint`, then `just test-scripts` |
| A skill under `.agents/skills/` | `just agents-sync`, then `just agents-check` |
| A workflow under `.github/workflows/` | `just lint` |
| Markdown | `just lint` (its `typos` spell-check) |
| `mise.toml` | `mise install`, then `just check` |

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

## Skills

Each skill owns one kind of change. Load the one whose subject you are working on.
The `translate-skills-*` issues add rows here as their skills land.

Skills are authored under `.agents/skills/` — the path Codex CLI reads — and mirrored
into `.claude/skills/`, the only path Claude Code reads. Claude Code is therefore the
tool that sees the generated copy rather than the authored one:

- Edit a skill only under `.agents/skills/`, then run `just agents-sync` and commit
  both trees together. Never hand-edit `.claude/skills/`, and never edit only one side;
  `just agents-check` reports any drift (`scripts/sync-agents.sh`).
- The mirror is a real, committed, byte-identical copy, never a symlink: Codex follows
  a linked directory into its subdirectories and registers a nested
  `references/SKILL.md` as a skill of its own. `.gitattributes` marks it
  `linguist-generated`, so GitHub collapses it in pull request diffs.
- `.claude/rules/` and `.claude/settings.json` are Claude Code-only and stay where they
  are; they are not mirrored.

| Skill | Load it when you are working on |
|---|---|
| `smart-commit` | committing and pushing changes: grouping them into Conventional Commits, excluding sensitive files |
| `create-pr` | opening or updating a pull request: the `just check` pre-check, title, template, and checklist |
| `tdd` | a behavior change in `MyAppCore`: writing a failing Swift Testing test before the implementation |

### Rules

The files under `.claude/rules/` load by path: each applies while you touch a file
matching its `paths:` globs.

| Rule | Loads when you touch |
|---|---|
| `.claude/rules/project.md` | `project.yml`, `Packages/**/Package.swift`, `mise.toml`, `.swiftlint.yml`, `.swiftformat`, `scripts/coverage.sh` |
| `.claude/rules/docs.md` | `docs/**/*.md`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` |
| `.claude/rules/swift.md` | `Packages/**/*.swift`, `App/**/*.swift` |
| `.claude/rules/testing.md` | `Packages/**/Tests/**`, `LaunchUITests/**` |

## Security and human approval

Get a human's sign-off before acting on any of these. No file in this repository
blocks them mechanically today — this section is the rule itself, not a description
of a check that enforces it.

- Touching `App/MyApp.entitlements`, a signing identity, or any signing,
  notarization, or release secret.
- Creating or pushing a release tag.
- Adding a new package dependency — see the dependency policy in
  `.claude/rules/project.md`.
- Weakening any gate: lowering the coverage floor, disabling or relaxing a SwiftLint
  rule, or widening a workflow's `permissions:`. If a gate looks wrong, say so and let
  a human decide.
- Any write to a remote: `git push`, `gh pr create`, `gh label create`, or any other
  remote write that is not performed by a script this repository ships (none does
  today).

## Repository scripts

Every script under `scripts/` follows these rules, whoever writes it
(`scripts/tests/lib.sh` is sourced, so it carries no shebang or `set` line of its own):

- `#!/usr/bin/env bash` and `set -euo pipefail`, and bash 3.2-compatible (macOS
  `/bin/bash`): no associative arrays, no `mapfile`/`readarray`, no `${var,,}`, and no
  `"${arr[@]}"` on a possibly empty array under `set -u` (use `${arr[@]+"${arr[@]}"}`).
- `shellcheck`-clean — `scripts/lint.sh` checks every tracked `*.sh`.
- Pinned tools are called by bare name; the caller provides PATH (`mise exec -- …`
  locally and in `just` recipes, `jdx/mise-action` in CI). Beyond that, assume only
  `git` and POSIX utilities, and no GNU- or BSD-only flag (`sed -i`, `readlink -f`,
  `mktemp -t`) — the scripts run on macOS and on CI's Ubuntu.
- Failure contract: the first stderr line is `ERR_<STAGE>_<WHAT>: <what failed>`, then
  `Expected:`, `Actual:`, and `Next:` lines (the next safe command); exit 1. List the
  codes in the script's header comment. Never print a secret value.
- Never assume the checkout is the only repository on the machine. A script that
  enumerates or rewrites tracked files refuses to run outside a git work tree (the
  `scripts/bootstrap.sh` pattern); a check that is meaningless outside one skips with a
  one-line notice instead. Each script's header states which it does.
- Every script directly under `scripts/` has a test file `scripts/tests/<script-name>_test.sh`
  built on `scripts/tests/lib.sh`, and `scripts/tests/run.sh` (`just test-scripts`,
  part of `just check` and CI's lint job) runs them all. A test works in a throwaway
  repository or temp directory, never the real checkout, and fakes external commands
  with `stub_command`. Known exceptions, each with its reason: `bootstrap.sh`
  (exercised end to end by CI's `bootstrap-smoke` job); `coverage.sh`,
  `smoke_launch.sh`, and `package_dmg.sh` (need Xcode and a build; exercised by the
  `test`, `app`, and `release` jobs). `bootstrap.sh` and `coverage.sh` also predate the
  failure contract and do not follow it yet.

## Enforcement layers

Later issues update the Enforcement layers table and gap list as they close each gap
named here — see the linked issue in each bullet.

The rules in this file are enforced by these layers, from mechanical to procedural:

| Layer | Fires on | Applies to | Holds |
|---|---|---|---|
| `.githooks/pre-commit` | `git commit` | anyone who ran `just install` | `scripts/lint.sh --staged-tree` — `swiftformat --lint` and `swiftlint --strict` on the staged Swift files |
| CI's `lint`, `test`, and `app` jobs (`.github/workflows/ci.yml`) | push to `main` and every pull request | everyone | the full gate: `scripts/lint.sh` (format, lint, shellcheck, actionlint, typos), the script tests (`scripts/tests/run.sh`), tests with the coverage floor, build, UI test, and Release smoke |
| This file | read at session start | every agent | everything else — the reasons behind the rules above |

These gaps are deliberate and stay open until their tracking issue closes them:

- **`git commit --no-verify` bypasses the hook**, and nothing in this repository
  blocks it. "Never bypass the hooks" holds as an instruction, and CI is the backstop.
- **Hooks are absent on a bare clone until `just install` runs**, because
  `core.hooksPath` is set by that recipe. #14 narrows this — it checks at
  `just install`/`just check` time — without closing it; CI stays the backstop for
  anyone who runs neither.
- **Nothing checks the `.claude/skills/` mirror automatically yet**: a skill edited
  without `just agents-sync` drifts until someone runs `just agents-check`. #17 wires
  that check into `just lint`, the pre-commit hook, and CI.
- **`main` has no branch protection**, so nothing requires CI to pass before a change
  lands on it. Tracked by #29.
- **`COVERAGE_MIN` can lower the coverage floor** through an environment variable
  (`scripts/coverage.sh`), so the 80% floor is a default, not a lock. Closed by #24.
- **The `PostToolUse` swiftformat hook in `.claude/settings.json` applies to Claude
  Code only.** It formats after an agent's edit on that one host; the git hook, not
  this hook, is the real gate.

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
