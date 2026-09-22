---
name: changing-gates
description: >
  Covers editing a file that enforces rather than implements: .swiftlint.yml,
  .swiftformat, Package.swift's strictSettings, mise.toml, .githooks/pre-commit,
  scripts/lint.sh, scripts/coverage.sh, the scripts/guard/ commit-time guard, or a
  .github/workflows/*.yml workflow. Use when a
  SwiftLint rule is added, disabled, or loosened, a SwiftFormat option changes, a target
  is added to Package.swift, a tool pin is added or bumped, a pre-commit section or a CI
  job or step is proposed, the coverage floor is touched, or the question is which gate
  would have caught a change — including what none of them sees.
---

# Changing Gates

**Owns:** a change to a file that enforces rather than implements — `.swiftlint.yml`,
`.swiftformat`, `Packages/HintjumpKit/Package.swift`'s `strictSettings`, `mise.toml`,
`.githooks/pre-commit`, `scripts/lint.sh`, `scripts/coverage.sh`, the commit-time guard
under `scripts/guard/`, and `.github/workflows/*.yml` — and which gate can see a given change at all. **Does not
own:** adding a package dependency (the Dependency Policy in `.claude/rules/project.md`);
the content of a repository-specific lint rule; how a
script under `scripts/` is written (`AGENTS.md`'s "Repository scripts"); the label set
in `.github/labels.yml` (`triaging-issues`).

Never weaken a gate to make a check pass: that rule is stated in `AGENTS.md`'s
"Security and human approval" and "Important Reminders" sections, and this skill does
not restate or relax it. A change that lowers, disables, or widens a gate needs a
human's sign-off, and its PR says why the removed protection no longer applies.

## The one rule every gate change shares

A gate file may narrow _what_ a shared script looks at; it never defines a rule of its
own. `scripts/lint.sh` is the single lint script: `just lint`
(`mise exec -- scripts/lint.sh`), the pre-commit hook (`--staged-tree`), and CI's `lint`
job all call it. A new check is therefore added to `scripts/lint.sh`, never inlined as a
command into `justfile`, `.githooks/pre-commit`, or a workflow `run:` step. The same
shape holds elsewhere: CI's `test` job calls `scripts/coverage.sh` (what `just test`
runs), and the `app` job calls `just build`, `just uitest`, and `just smoke`.

A check in `scripts/lint.sh` is three edits, not one:

- the `run …` line, so the check runs and a failure is collected without stopping the
  checks after it;
- the tool in `REQUIRED_TOOLS` for its mode, so a missing tool fails as
  `ERR_LINT_TOOL_MISSING` instead of as a confusing linter error;
- the tool in `mise.toml` and in the `install_args` of ci.yml's `lint` job. That job
  runs on `ubuntu-latest` and installs only the Linux-capable subset, so a macOS-only
  tool cannot join `scripts/lint.sh` at all — it belongs in a macOS job.

`scripts/tests/run.sh` (`just test-scripts`, part of `just check` and CI's `lint` job)
is a gate on the gates: `scripts/tests/lint_test.sh` pins `scripts/lint.sh`'s argument
and tool checks, `scripts/tests/pre-commit-skills_test.sh` pins the hook's "Skills
mirror" section, and `scripts/tests/check-staged_test.sh` pins its "Staged guard"
section. A change to either file keeps its test green, and a new script under
`scripts/` gets a test as `AGENTS.md`'s "Repository scripts" requires.

## `.swiftlint.yml`

`strict: true` makes every warning an error, and `opt_in_rules: [all]` enables every
opt-in rule, so a new SwiftLint release can add rules that fire on a pin bump. Every
entry in `disabled_rules` carries a one-line trailing reason; a new entry without one
is incomplete, and removing a rule needs explicit approval
(`.claude/rules/project.md`). Prefer an inline `// swiftlint:disable:next <rule>` with
a reason when only one site needs the exception — a global disable widens the gate for
every future file. Repository-specific rules live under `custom_rules:`; there are two.

`no_ui_import_in_core` keeps `HintjumpCore` from importing a UI or OS-integration
framework — SwiftUI, AppKit, UIKit, Cocoa, ApplicationServices, Carbon, and
ServiceManagement — attributed and kind-qualified spellings included;
`ArchitectureBoundaryTests` in
`HintjumpCoreTests` enforces the same boundary a second way. Its module list and the
test's `forbiddenModules` change together, in one commit — adding a framework to one
and not the other leaves the boundary enforced once. Adding to that list strengthens
the gate and is the routine direction; removing from it is weakening one. `os` and
`OSLog` are deliberately not on it, so Core can log (`docs/architecture.md` › Logging);
a test case pins their absence. Its
`included` regex names the
package and module, so a new Core-like target means widening it and the test's path.
The sibling boundary — `HintjumpUI` and `HintjumpPlatform` never importing each other — is
held by `ArchitectureBoundaryTests` alone, with no lint-rule twin.

`no_print_in_sources` rejects `print(`, `debugPrint(`, and `NSLog(` under
`Packages/*/Sources/` and `App/`, because an `open`-launched `.app` discards stdout:
shipped code logs through `HintjumpCore`'s `AppLog` instead (`.claude/rules/swift.md` ›
Logging). Four parts of it are load-bearing, and a widening edit usually breaks one:

- `match_kinds: [identifier]` spares a `print(` inside a comment or a string literal —
  only a real call site is an identifier;
- `[^\w.]` before the name spares `blueprint(` and member calls like `.print()`;
- `included` and `excluded` are substring matches against the *whole* path, never
  repository-relative globs, so both are written to survive any ancestor directory.
  `App/[^/]+\.swift$` allows exactly one component after `App/`, because the shell is
  flat; `Packages/[^/]+/Sources/[^/]+/.+\.swift$` requires a module directory, so
  `Packages/*/Tests/` cannot satisfy it. Loosen either and a checkout under `~/App/` —
  or under any path with that shape, which `scripts/bootstrap.sh` readily produces —
  starts matching test files;
- `excluded: '(^|/)[A-Za-z0-9]*Tests/'` is the second line of defence for the same
  worry: no `*Tests/` directory is ever linted by this rule. Test code prints freely.

Matching a path *suffix* rather than a repository-relative path is also what keeps the
rule firing over the temp tree the pre-commit hook exports with
`git checkout-index --prefix=`. It catches a call site, not a deliberate bypass:
`Swift.print(` is out of its reach and is PR review's to catch.

`analyzer_rules` is deliberately absent: those run only under
`swiftlint analyze` with a compiler log, which no gate here invokes. `trailing_comma`
is set to agree with SwiftFormat; the two tools must never disagree about one file.

## `.swiftformat`

`just fmt` applies it (`swiftformat .`); `scripts/lint.sh` only checks
(`swiftformat --lint`), so a formatting change surfaces in `just lint`, the hook, and
CI, never as a silent rewrite. Changing an option reformats the whole tree: land the
option and the resulting reformat in the same commit, and check that the output still
passes `swiftlint --strict`. `--swiftversion` follows the package's tools version.

## `Package.swift`'s `strictSettings`

`strictSettings` holds `.swiftLanguageMode(.v6)` and `.treatAllWarnings(as: .error)`.
It is not inherited: each target passes `swiftSettings: strictSettings` itself, so a new
target — source or test — must opt in explicitly, or it compiles without Swift 6
data-race errors and with warnings allowed. Removing an entry, or adding an
`unsafeFlags` or a per-target exception, is weakening a gate.

## `mise.toml`

It pins every CLI tool the gates call; scripts call those tools by bare name and the
caller provides PATH. A pin is bumped deliberately, one commit per bump, after
`just check` passes (`.claude/rules/project.md`'s Toolchain Pinning). A SwiftLint or
SwiftFormat bump is a gate change in its own right: new rules or formatting may fire,
and the fix is to the code or a reasoned `disabled_rules` entry, never to skip the bump
silently. The Xcode pin lives in `.xcode-version`, not here.

## `scripts/coverage.sh`

It gates on line coverage of `Sources/HintjumpCore/` only, by filtering llvm-cov's report
to that path. `HintjumpUI` and `HintjumpPlatform` are outside it because an adapter or a view
holds translation rather than a decision (`docs/architecture.md` › Ports and adapters) —
not because nothing links them: `HintjumpPlatformTests` links `HintjumpPlatform`, and its
tests are skipped unless `RUN_LOCAL_MACHINE_TESTS=1` (`just test-local`), so they add no
coverage under `just test` either way. Measuring Platform would therefore gate on
whether a human opted in, which is why the filter is a path and not a target list. The
floor is
`readonly COVERAGE_FLOOR=80` in the script and nothing else — no environment variable or
flag moves it, so every change to it is a reviewed diff of this file, and a change is
only ever a raise. The script rejects the environment override it used to read with
`ERR_COVERAGE_OVERRIDE_REMOVED` before any test runs, rather than silently ignoring it;
`scripts/tests/coverage_test.sh` holds that. Adding a new way to set the floor from a
recipe, workflow, or hook is lowering it by another route.

## `.githooks/pre-commit`

Independent sections, each scoped by the staged paths it cares about, none exiting
early — a commit that skips one section must still reach every other. Each section
calls a shared script: "Swift lint" exports the staged Swift blobs and runs
`scripts/lint.sh --staged-tree`; "Skills mirror" exports both skill trees from the
index and runs `scripts/sync-agents.sh --check --root`; "Staged guard" runs
`scripts/check-staged.sh` on every commit that stages any change (see
`scripts/guard/` below). All three check the staged content, not the worktree. A new section is appended below the layout-rule comment, and one that
needs a scratch directory takes it from `new_temp_dir`, which registers it in
`CLEANUP_DIRS` for the one shared `EXIT` trap — a second `trap … EXIT` would replace the
first and leak its directory. The hook only reaches clones that ran `just install`
(`core.hooksPath`); `scripts/verify-hooks.sh` (`just install`'s last step, and `just
check`'s first) fails loudly when that config did not stick or `.githooks/pre-commit`
lost its executable bit, narrowing — not closing — that gap: a contributor who runs
neither still commits without the hook, so CI stays the backstop. It skips under CI or
the named `ALLOW_MISSING_GIT_HOOKS` opt-out, for an environment that genuinely cannot
have git hooks.

## `scripts/guard/`

`scripts/check-staged.sh` (the hook's "Staged guard" section) classifies each staged
path with `scripts/guard/paths.sh` first, and only scans the staged blob of a path that
passes with `scripts/guard/credentials.sh`. Staged deletions are never inspected: they
cannot add a secret, and blocking one would block the commit that removes a secret.
Those two files are the list — read them for exactly what is checked:

- **Blocked by path:** `.env` and `.env.*` (except `.example`/`.sample`/`.template`),
  any `secrets` path segment, signing material and credential files (`.p12`,
  `.pfx`, `.p8`, provisioning profiles, keychains, `*key*.pem`, `.netrc`,
  `credentials.json`, `secrets.json`, `private-key.*`), and `Local.xcconfig` — the
  per-machine Debug signing identity `Config/Debug.xcconfig` optionally includes,
  which is gitignored as well.
- **Blocked by content:** literal patterns for a PEM private-key header, GitHub tokens,
  and AWS access key ids. It prints the category, never the matched text.
- **Deliberately not blocked:** `.cer` and `.certSigningRequest` (public), `.key`
  (collides with Keynote documents), a regenerated `Package.resolved`, and anything
  that needs judgment rather than a pattern — no entropy heuristic. Whether a commit
  *should* contain what it contains stays in PR review.

A new pattern starts from a real false negative and lands with a fixture case in
`scripts/tests/guard-paths_test.sh` or `scripts/tests/guard-credentials_test.sh`.
Fixtures are assembled at runtime from pieces that do not match on their own, so no
committed file — the tests included — is secret-shaped; GitHub push protection is the
server-side layer and would refuse such a file too. Removing a pattern or a path rule is
weakening a gate. `git commit --no-verify` skips this guard with every other hook
section, and no CI job reruns it: that gap is listed in `AGENTS.md`'s "Enforcement
layers".

## `.github/workflows/`

`ci.yml` splits into `lint` (ubuntu: `scripts/lint.sh`, then `scripts/tests/run.sh`),
`test` (macOS: `scripts/coverage.sh`), `app` (macOS: `just build`, `just uitest`,
`just smoke`), `bootstrap-smoke` (macOS: `scripts/bootstrap.sh` on a clone, then a test
and build of the renamed app), and `zizmor` (workflow security lint). Which layer holds
what is `AGENTS.md`'s "Enforcement layers" table; read it rather than re-deriving it.

Conventions every workflow here follows, which `actionlint` (in `scripts/lint.sh`) and
the `zizmor` job partly check and review holds for the rest:

- every `uses:` of a remote action is pinned to a full commit SHA with a trailing
  `# vX.Y.Z` comment; a local `./.github/actions/…` action is exempt;
- a top-level `permissions:` as narrow as the work allows, and every job has a
  `timeout-minutes`;
- `actions/checkout` runs with `persist-credentials: false`;
- a new check goes into an existing job unless it needs a different runner, trigger, or
  permission footprint. Widening `permissions:` or adding a workflow that writes is a
  security-relevant change that needs sign-off, not a routine CI edit.

## What no gate here sees

Nothing boots the app and asserts behavior beyond two checks: `scripts/smoke_launch.sh`
(`just smoke`) builds Release, verifies the code signature, launches the binary, and
asserts only that the process stays alive; `LaunchUITests/LaunchTests.swift`
(`just uitest`) asserts that a window appears and one increment click updates the
counter. Any other UI behavior, `HintjumpUI` and `HintjumpPlatform` code paths (both outside
the coverage floor — an adapter's real OS call is exercised by no *gate*: it has a test,
in `Tests/HintjumpPlatformTests`, that only a human runs with `just test-local`, because a
runner has no GUI session and no TCC grants), the signed and notarized release (built only on a tag push by `release.yml`), and
entitlements or signing settings are places a change can be wrong while every gate
passes. Debug signing is now one of those settings: `Config/Debug.xcconfig` may
`#include?` an uncommitted `Config/Local.xcconfig`, so what a developer's Debug build
is signed with is by design invisible to every gate — which is why Release reads no
xcconfig, and why `just smoke` stays the check that Release signing is intact. A gate proposed to close such a gap is a real gate change and belongs in the PR
as one.
