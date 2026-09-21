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
- The pre-commit hook gains a "Staged guard" section, run on every commit that stages a
  change: `scripts/check-staged.sh` refuses a secret-shaped staged path
  (`scripts/guard/paths.sh`: `.env*` except samples, `secrets/`, `.p12`/`.pfx`/`.p8`,
  provisioning profiles, keychains, and named credential files) and credential-shaped
  staged content (`scripts/guard/credentials.sh`: a private-key header, GitHub tokens,
  AWS access key ids), never printing the matched text and never inspecting a staged
  deletion; `smart-commit` and `changing-gates` point at `scripts/guard/` instead of
  keeping their own list
- Harness-conformance checks under `scripts/checks/` (`just check-harness`, run by
  `just check` before `just test` and by CI's `lint` job): every `just <recipe>` in
  `AGENTS.md` exists, every workflow has a top-level `permissions:` and every non-local
  `uses:` in a workflow or composite action is pinned to a full SHA with a `# v…`
  comment, every `SKILL.md` frontmatter is exactly a matching `name` and a
  `description`, and `AGENTS.md`'s Skills table matches `.agents/skills/`; each failure
  mode is pinned by `scripts/tests/checks_test.sh`
- `.github/rulesets/main.json` defines the intended `main` branch ruleset (PR
  required, checks green, no force-push or deletion) as code; `scripts/apply-ruleset.sh`
  (`just ruleset`) creates or updates it via `gh` for a repository admin, mapping a
  plan-gated API refusal and any other refusal to distinct named errors
- `MyAppCore` is mechanically kept free of UI frameworks, twice: a SwiftLint custom rule
  (`no_ui_import_in_core` in `.swiftlint.yml`) and a Swift Testing suite
  (`ArchitectureBoundaryTests`) both reject `SwiftUI`, `AppKit`, `UIKit`, and `Cocoa`
  imports in `Sources/MyAppCore`, including attributed and kind-qualified spellings
- Two skills: `writing-repo-scripts` (why the repository scripts are bash, refusing or
  skipping outside a git checkout, the stderr contract by worked example, and testing
  with `scripts/tests/lib.sh`, pointing at `AGENTS.md`'s "Repository scripts" for the
  rules) and `starting-an-app` (what `scripts/bootstrap.sh` renames and how, and what a
  new app keeps, including its labels and branch ruleset)

### Changed

- `just build` and `just uitest` isolate DerivedData under `build/`, so
  `just clean` now removes everything the toolchain produced
- `scripts/bootstrap.sh` resets `CHANGELOG.md` for the new project and prints a
  verify-first next-steps list
- `scripts/bootstrap.sh`'s next steps and `README.md`'s "Using This Template" add
  `just labels` for the new repository, and `just ruleset` as an optional, admin-only
  last step once the bootstrap commit is on `main`
- `just lint`, the pre-commit hook, and CI's lint job all call one script,
  `scripts/lint.sh`; `typos` is pinned in `mise.toml` and runs in `just lint`
  (CI's separate spell-check job is folded into the lint job)
- The pre-commit hook runs each check as its own section scoped by staged paths,
  with no early exit when no Swift file is staged
- `typos` also spell-checks the dot-directories (`.agents/`, `.claude/`, `.github/`,
  `.githooks/`), which it skipped by default; `.git/` is excluded
- `just test-scripts` runs `scripts/tests/run.sh` through `mise exec --`, since the
  harness-check tests call the pinned `just`; CI's lint job installs `just` too
- The coverage floor is `readonly COVERAGE_FLOOR=80` in `scripts/coverage.sh` and moves
  only by a reviewed diff: the `COVERAGE_MIN` environment override is removed, and
  setting it now fails with `ERR_COVERAGE_OVERRIDE_REMOVED` before any test runs
  (`scripts/tests/coverage_test.sh`)
- Dependency review fails a pull request that adds a dependency outside the permissive
  license allow-list in `.claude/rules/project.md` (MIT, Apache-2.0, BSD-2-Clause,
  BSD-3-Clause, ISC, 0BSD, Zlib), via the action's `allow-licenses`
- `.claude/rules/project.md` holds the review record a new SwiftPM dependency needs
  (need, continuity, license, weight, build-time code, platforms, advisories) and how to
  declare, add, and bump one without hand-editing `Package.resolved`; it now also loads
  when `Package.resolved` is touched

[Unreleased]: https://github.com/your-username/my-app/commits/main
