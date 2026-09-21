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
just fix       # Format, auto-fix SwiftLint violations, then run just lint
just lint      # Lint (scripts/lint.sh: swiftformat --lint + swiftlint --strict + shellcheck + actionlint + typos)
just verify-hooks  # Verify the git hooks are installed and executable (scripts/verify-hooks.sh)
just test-scripts  # Run the plain-bash tests for scripts/ (scripts/tests/run.sh)
just check-harness # Re-assert the harness's claims about itself (scripts/checks/run-all.sh)
just test      # Run tests with the 80% coverage floor on MyAppCore
just test-fast CounterTests  # Run only the matching tests, no coverage floor (iteration only)
just build     # Build the app (Debug)
just run       # Build (Debug) and launch the app, left running until you quit it
just uitest    # Run the XCUITest launch test
just smoke     # Build Release and assert the app launches
just check     # Run all checks: verify-hooks → fmt → lint → test-scripts → check-harness → test → build
just agents-sync   # Regenerate the .claude/skills/ mirror from .agents/skills/
just agents-check  # Fail if .claude/skills/ differs from .agents/skills/
just clean     # Remove build artifacts and the generated project
just labels    # Create/update GitHub labels from .github/labels.yml (never deletes)
just ruleset   # Create/update the "main" branch ruleset from .github/rulesets/main.json (admin-only)
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
| An adapter under `Packages/MyAppKit/Sources/MyAppPlatform/` | `just test` (it compiles under `swift test`); `just build` if `App/` wires it |
| Formatting or style of any Swift file | `just lint` |
| A SwiftLint or SwiftFormat violation that may be auto-fixable | `just fix` (formats, runs `swiftlint --fix`, then `just lint` reports what still needs a hand edit) |
| One Core suite, while iterating | `just test-fast <filter>` (e.g. `just test-fast CounterTests`) — no coverage floor, so finish with `just test` |
| `project.yml` | `just generate && just build` |
| A test under `LaunchUITests/`, or launch behavior | `just uitest` |
| The Release configuration, or anything only a Release launch shows | `just smoke` |
| A shell script under `scripts/` (including the sourced `scripts/guard/*.sh`), or `.githooks/pre-commit` | `just lint`, then `just test-scripts` |
| `scripts/verify-hooks.sh` | `just lint`, then `just test-scripts`; `just verify-hooks` for the check itself |
| A harness check under `scripts/checks/` (including the sourced `scripts/checks/lib.sh`) | `just lint`, then `just test-scripts`; `just check-harness` for the checks themselves |
| A `just` recipe name, a workflow's `uses:` or `permissions:`, a skill's frontmatter, or the Skills table | `just check-harness` |
| A skill under `.agents/skills/` | `just agents-sync`, then `just agents-check` and `just check-harness` |
| A workflow under `.github/workflows/` | `just lint`, then `just check-harness` |
| Markdown | `just lint` (its `typos` spell-check) |
| `mise.toml` | `mise install`, then `just check` |
| `.github/labels.yml`, or an issue form under `.github/ISSUE_TEMPLATE/` | `just lint` (its `typos` spell-check); `scripts/tests/sync-labels_test.sh` for `scripts/sync-labels.sh` itself |
| `.github/rulesets/main.json`, or `scripts/apply-ruleset.sh` | `scripts/tests/apply-ruleset_test.sh` |

## Architecture

```
App/                        # Thin shell: @main entry point + resources, NO logic.
                            #   The composition root: builds MyAppPlatform adapters
                            #   and hands them to Core view models
Packages/MyAppKit/
├── Sources/MyAppCore/      # Domain logic + view models + the ports (protocols) OS
│                           #   code is reached through — platform-agnostic, no
│                           #   SwiftUI/AppKit/UIKit/Cocoa/ApplicationServices/
│                           #   Carbon/ServiceManagement import (enforced by lint
│                           #   and test), coverage-gated at 80%
├── Sources/MyAppUI/        # SwiftUI views — thin, delegate to Core view models
├── Sources/MyAppPlatform/  # OS-integration adapters behind Core ports (AppKit and
│                           #   friends) — translation only, no domain logic, and
│                           #   deliberately outside the coverage floor
└── Tests/MyAppCoreTests/   # Swift Testing suites
LaunchUITests/              # XCUITest launch guarantee (XCTest by necessity)
```

- New logic goes in `MyAppCore` with tests; views only render Core state
- The dependency direction is one-way: Core ← UI and Core ← Platform, both ← App.
  `MyAppUI` and `MyAppPlatform` are siblings and never import each other
- OS integration goes in `MyAppPlatform` as an adapter behind a `Sendable` port Core
  declares; a Core test substitutes a fake for that port, and `App/` picks the real one.
  Adapters translate and never decide — a decision belongs in Core, which is why
  Platform stays outside the coverage floor (`scripts/coverage.sh` measures Core only).
  The worked example is `FrontmostAppProviding` / `WorkspaceFrontmostAppProvider`
  (`docs/architecture.md` › Ports and adapters)
- `MyAppCore` never imports SwiftUI, AppKit, UIKit, Cocoa, ApplicationServices, Carbon,
  or ServiceManagement — in any spelling, including `@preconcurrency import AppKit` and
  `import struct SwiftUI.Color`. SwiftPM cannot block a
  system framework, so this is enforced twice: `.swiftlint.yml`'s `no_ui_import_in_core`
  and the `ArchitectureBoundaryTests` suite; their module lists change together
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
| `changing-gates` | a file that enforces rather than implements: `.swiftlint.yml`, `.swiftformat`, `Package.swift`'s `strictSettings`, `mise.toml`, `.githooks/pre-commit`, `scripts/lint.sh`, `scripts/coverage.sh`, the `scripts/guard/` commit-time guard, or a workflow — and which gate would catch a change |
| `triaging-issues` | filing or triaging an issue: the labels in `.github/labels.yml` (`just labels`), priority tiers, and the `Depends on #N` convention |
| `authoring-skills` | adding, editing, or reviewing a skill: authoring under `.agents/skills/`, the `just agents-sync` mirror, frontmatter, layout, and size limits |
| `updating-docs` | deciding whether a change owes a documentation update and which surface it lands on: `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `docs/*.md`, a skill, or a `///` comment |
| `writing-repo-scripts` | writing or testing a shell script under `scripts/`, `.githooks/pre-commit`, or `scripts/tests/`: why bash, refusing or skipping outside a git checkout, the stderr contract by example, and `scripts/tests/lib.sh` |
| `starting-an-app` | turning this template into a new app: `scripts/bootstrap.sh`'s rename, what the new repository keeps, and its `just labels` and `just ruleset` setup |

### Rules

The files under `.claude/rules/` load by path: each applies while you touch a file
matching its `paths:` globs.

| Rule | Loads when you touch |
|---|---|
| `.claude/rules/project.md` | `project.yml`, `Packages/**/Package.swift`, `Packages/**/Package.resolved`, `mise.toml`, `.swiftlint.yml`, `.swiftformat`, `scripts/coverage.sh` |
| `.claude/rules/docs.md` | `docs/**/*.md`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` |
| `.claude/rules/swift.md` | `Packages/**/*.swift`, `App/**/*.swift` |
| `.claude/rules/testing.md` | `Packages/**/Tests/**`, `LaunchUITests/**` |

## Security and human approval

Only what is mechanically decidable is blocked at commit time; whether a commit
*should* contain what it contains stays in PR review. See `scripts/guard/` for exactly
what is checked: the pre-commit hook's "Staged guard" section (`scripts/check-staged.sh`)
refuses a secret-shaped staged path or credential-shaped staged content.

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
- Any write to a remote: `git push`, `gh pr create`, or any other remote write that
  is not performed by a script this repository ships. `scripts/sync-labels.sh`
  (`just labels`) is such a script for labels: it only ever creates or updates a
  label `.github/labels.yml` declares, via `gh label create --force`, and never
  deletes one — but running it against the live repository still needs sign-off
  before its first run there, the same as any other remote write. `scripts/apply-ruleset.sh`
  (`just ruleset`) is the same kind of script for branch protection: it only ever
  creates or updates the ruleset named "main" from `.github/rulesets/main.json`,
  needs repository admin permissions to succeed, and still needs sign-off before
  its first run against the live repository.

## Repository scripts

Every script under `scripts/` follows these rules, whoever writes it
(`scripts/tests/lib.sh`, `scripts/checks/lib.sh`, and the `scripts/guard/*.sh`
libraries are sourced, so they carry no shebang or `set` line of their own). The
reasons behind them, with worked examples, are in the `writing-repo-scripts` skill:

- `#!/usr/bin/env bash` and `set -euo pipefail`, and bash 3.2-compatible (macOS
  `/bin/bash`): no associative arrays, no `mapfile`/`readarray`, no `${var,,}`, and no
  `"${arr[@]}"` on a possibly empty array under `set -u` (use `${arr[@]+"${arr[@]}"}`).
- `shellcheck`-clean — `scripts/lint.sh` checks every tracked `*.sh`.
- Pinned tools are called by bare name; the caller provides PATH (`mise exec -- …`
  locally and in `just` recipes, `jdx/mise-action` in CI). Beyond that, assume only
  `git` and POSIX utilities, and no GNU- or BSD-only flag (`sed -i`, `readlink -f`,
  `mktemp -t`) — the scripts run on macOS and on CI's Ubuntu. A script whose job is
  a GitHub write (`scripts/sync-labels.sh`, `scripts/apply-ruleset.sh`) may also
  depend on `gh`: like `git`, it is assumed on PATH rather than routed through
  `mise exec --`, since it is not a mise tool (see `mise.toml`) — its tests stub it
  out, so `just check` never needs the real binary.
- Failure contract: the first stderr line is `ERR_<STAGE>_<WHAT>: <what failed>`, then
  `Expected:`, `Actual:`, and `Next:` lines (the next safe command); exit 1. List the
  codes in the script's header comment. Never print a secret value.
- Never assume the checkout is the only repository on the machine. A script that
  enumerates or rewrites tracked files refuses to run outside a git work tree (the
  `scripts/bootstrap.sh` pattern); a check that is meaningless outside one skips with a
  one-line notice instead. Each script's header states which it does.
- Every script directly under `scripts/` has a test file `scripts/tests/<script-name>_test.sh`
  built on `scripts/tests/lib.sh`, and `scripts/tests/run.sh` (`just test-scripts`,
  part of `just check` and CI's lint job) runs them all — concurrently, so a test file
  must share no state with any other: its own throwaway repository or temp directory,
  its own stubs, and only read-only use of the checkout. The runner itself is covered
  by `scripts/tests/run_test.sh`. A test works in a throwaway
  repository or temp directory, never the real checkout, and fakes external commands
  with `stub_command`. A sourced library under `scripts/guard/` gets its own test file
  too, `scripts/tests/guard-<library>_test.sh` (`guard-paths_test.sh`,
  `guard-credentials_test.sh`). The harness checks under `scripts/checks/`, their
  runner `run-all.sh`, and their sourced `lib.sh` share one test file,
  `scripts/tests/checks_test.sh`, which builds a fixture tree per failure mode and
  points each check at it with `--root`. Known exceptions, each with its reason:
  `bootstrap.sh` (exercised end to end by CI's `bootstrap-smoke` job); `coverage.sh`,
  `smoke_launch.sh`, and `package_dmg.sh` (need Xcode and a build; exercised by the
  `test`, `app`, and `release` jobs) — `coverage.sh` still has a partial test file,
  `scripts/tests/coverage_test.sh`, which stubs `swift` to cover its rejection of the
  removed environment override and its floor comparison, but not a real coverage run.
  `bootstrap.sh` also predates the failure contract and does not follow it yet, and
  neither does `coverage.sh`'s below-the-floor failure.

## Enforcement layers

Later issues update the Enforcement layers table and gap list as they close each gap
named here — see the linked issue in each bullet.

The rules in this file are enforced by these layers, from mechanical to procedural:

| Layer | Fires on | Applies to | Holds |
|---|---|---|---|
| `.githooks/pre-commit` | `git commit` | anyone who ran `just install` | `scripts/lint.sh --staged-tree` — `swiftformat --lint` and `swiftlint --strict` on the staged Swift files |
| `.swiftlint.yml`'s `no_ui_import_in_core` custom rule and `ArchitectureBoundaryTests` (`Packages/MyAppKit/Tests/MyAppCoreTests/`) | the lint rule: `git commit` (via the hook's `swiftlint --strict`), `just lint`, and CI's `lint` job; the test: `just test` and CI's `test` job | every author | `MyAppCore` imports none of SwiftUI, AppKit, UIKit, Cocoa, ApplicationServices, Carbon, or ServiceManagement, including attributed and kind-qualified imports — enforced twice, so removing either mechanism leaves the other. The test alone also holds the sibling boundary: `MyAppUI` and `MyAppPlatform` never import each other |
| `scripts/verify-hooks.sh` (`just install`'s last step, and `just check`'s first) | `just install` and `just check` | anyone who runs either | git resolves the hooks directory to `.githooks/` and `.githooks/pre-commit` is executable — skips under CI or the `ALLOW_MISSING_GIT_HOOKS` opt-out |
| `scripts/check-staged.sh` (the hook's "Staged guard" section; the rules live in `scripts/guard/`) | `git commit` when any change is staged, with or without a Swift file | anyone who ran `just install` | no obviously secret-shaped path (`.env*`, `secrets/`, signing material) or credential-shaped content (private-key header, GitHub token, AWS access key id) lands in a commit; staged deletions are never inspected |
| `scripts/sync-agents.sh --check` (the hook's "Skills mirror" section, `just lint`, and CI's `lint` job) | `git commit` when a staged path is under `.agents/skills/` or `.claude/skills/`; unconditionally on `just lint` and CI | every author | `.agents/skills/` and `.claude/skills/` stay byte-identical |
| `scripts/checks/run-all.sh` (`just check-harness`, part of `just check` before `just test`) | `just check-harness`, `just check`, and CI's `lint` job | every author | the harness's claims about itself stay true — every `just <recipe>` in this file exists, every workflow has a top-level `permissions:` and every non-local `uses:` (workflows and composite actions) is pinned to a full SHA with a `# v…` comment, every skill's frontmatter is exactly a matching `name` and a `description`, and the Skills table matches `.agents/skills/` |
| CI's `lint`, `test`, and `app` jobs (`.github/workflows/ci.yml`) | push to `main` and every pull request | everyone | the full gate: `scripts/lint.sh` (format, lint, shellcheck, actionlint, typos, the skills-mirror check), the script tests (`scripts/tests/run.sh`), the harness checks (`scripts/checks/run-all.sh`), tests with the coverage floor, build, UI test, and Release smoke |
| This file | read at session start | every agent | everything else — the reasons behind the rules above |

These gaps are deliberate and stay open until their tracking issue closes them:

- **`git commit --no-verify` bypasses the hook**, and nothing in this repository
  blocks it. "Never bypass the hooks" holds as an instruction, and CI is the backstop —
  except for the staged guard, which no CI job reruns over a pull request's diff:
  GitHub push protection and secret scanning are the server-side layer for secrets.
- **Hooks are absent on a bare clone until `just install` runs**, because
  `core.hooksPath` is set by that recipe. `scripts/verify-hooks.sh` narrows this: it
  fails loudly at `just install` and `just check` time when git does not resolve the
  hooks directory to `.githooks/` or `.githooks/pre-commit` is not executable, so a
  clone whose hook silently failed to install no longer looks identical to one that
  succeeded. It does not close the gap — a contributor who runs neither `just install`
  nor `just check` still commits without hooks — so CI stays the backstop.
  `ALLOW_MISSING_GIT_HOOKS=1` opts out for an environment that genuinely cannot have
  git hooks (e.g. a read-only or sandboxed checkout); every failure names it.
- **Whether `main`'s ruleset is actually in force is invisible from the checkout.**
  The intended ruleset — PR required, checks green, no force-push or deletion — is
  defined as code in `.github/rulesets/main.json`; `just ruleset`
  (`scripts/apply-ruleset.sh`) creates or updates it via the GitHub API for whoever
  runs it as a repository admin. Nothing in the checkout verifies that it was
  actually applied to the live repository — that is visible only via
  `gh api repos/{owner}/{repo}/rulesets`, never from a git checkout. "Use this
  template" does not copy rulesets, so every repository created from this template
  still needs its own admin to run `just ruleset` once.
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
