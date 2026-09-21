# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial template: XcodeGen-generated app shell over a local Swift package
  with a Core/UI split and a working counter placeholder
- Swift Testing suite with an enforced 80% line-coverage floor on `MyAppCore`
  (`scripts/coverage.sh`)
- XCUITest launch test and a Release-build smoke script (`scripts/smoke_launch.sh`)
- `scripts/bootstrap.sh` deterministic template initializer: renames `MyApp`
  and replaces every placeholder (`my-app`, `com.example`, `your-username`,
  `Your Name`, `you@example.com`) across tracked files
- Strict tooling from day one: Swift 6 language mode, warnings-as-errors,
  SwiftLint strict with all opt-in rules, SwiftFormat, pinned via mise
- Hardened CI: SHA-pinned actions, least-privilege permissions, zizmor,
  typos, OpenSSF Scorecard, Dependabot with cooldown, OSV scan,
  dependency review, and a template bootstrap smoke job
- Secret-gated release pipeline: DMG packaging, Developer ID signing,
  notarization, and build-provenance attestation
- `AGENTS.md` and path-scoped `.claude/rules/` for AI-assisted development
- ShellCheck joins the lint gate (`just lint` and CI) for every repo shell script
- The launch UI test writes an `.xcresult` bundle; CI uploads it when the job fails
- The release pipeline smoke-tests the signed Release app before packaging the DMG
- A repository-script contract in `AGENTS.md` (`## Repository scripts`) and a
  plain-bash test runner for `scripts/` (`scripts/tests/run.sh`, `just test-scripts`),
  run by `just check` and CI's lint job; `scripts/lint.sh` errors now carry
  `Expected:`/`Actual:`/`Next:` lines
- `AGENTS.md` gains a narrowest-check table, a skill and rule index, the actions
  that need human approval, and the enforcement layers with their known gaps
- Release runs are serialized per tag via a workflow `concurrency` group
- `.xcode-version` is the single source of truth for the CI Xcode pin;
  `just install` warns when the local Xcode differs
- CodeQL static analysis of the Swift package (weekly and on `main` pushes)
- Skills are authored once under `.agents/skills/` (read by Codex CLI) and mirrored
  byte for byte into `.claude/skills/` by `scripts/sync-agents.sh`
  (`just agents-sync`; `just agents-check` reports drift); `.gitattributes` marks the
  mirror as generated
- `ContentView` accepts an injected view model and ships `#Preview` configurations
- `just lint`, the pre-commit hook (a new "Skills mirror" section, scoped to commits
  that stage a path under `.agents/skills/` or `.claude/skills/`), and CI's lint job
  now all fail when the two skill trees drift, via `scripts/sync-agents.sh --check`
- `.github/labels.yml` declares this repository's GitHub label taxonomy as code;
  `scripts/sync-labels.sh` (`just labels`) creates or updates each label from it,
  never deleting one it does not mention, and a `.github/ISSUE_TEMPLATE/task.yml`
  form files repository chores with `chore` and an unset priority
- Two skills under `.agents/skills/`, translated to this stack: `changing-gates`
  (editing a lint, format, compiler, hook, coverage, or CI gate, and which gate sees a
  change) and `triaging-issues` (the label taxonomy in `.github/labels.yml`, priority
  tiers, and the `Depends on #N` convention)
- Two more skills under `.agents/skills/`, translated to this stack: `authoring-skills`
  (authoring a skill once under `.agents/skills/`, the `just agents-sync` mirror, and
  what no check verifies yet) and `updating-docs` (which documentation surface a change
  lands on, including `CHANGELOG.md` and `docs/`)
- `scripts/verify-hooks.sh` (`just verify-hooks`) checks that git really resolves the
  hooks directory to `.githooks/` and that `.githooks/pre-commit` is executable, run at
  the end of `just install` and as the first step of `just check`; it skips under CI or
  the named `ALLOW_MISSING_GIT_HOOKS=1` opt-out, for an environment that genuinely
  cannot have git hooks

### Changed

- `just build` and `just uitest` isolate DerivedData under `build/`, so
  `just clean` now removes everything the toolchain produced
- `scripts/bootstrap.sh` resets `CHANGELOG.md` for the new project and prints a
  verify-first next-steps list
- `just lint`, the pre-commit hook, and CI's lint job all call one script,
  `scripts/lint.sh`; `typos` is pinned in `mise.toml` and runs in `just lint`
  (CI's separate spell-check job is folded into the lint job)
- The pre-commit hook runs each check as its own section scoped by staged paths,
  with no early exit when no Swift file is staged
- `typos` also spell-checks the dot-directories (`.agents/`, `.claude/`, `.github/`,
  `.githooks/`), which it skipped by default; `.git/` is excluded

[Unreleased]: https://github.com/your-username/my-app/commits/main
