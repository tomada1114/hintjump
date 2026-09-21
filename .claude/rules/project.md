---
paths:
  - "project.yml"
  - "Packages/**/Package.swift"
  - "Packages/**/Package.resolved"
  - "mise.toml"
  - ".swiftlint.yml"
  - ".swiftformat"
  - "scripts/coverage.sh"
---

## Dependency Policy

- The template ships with ZERO package dependencies — keep it that way unless the app truly needs one
- Before adding a dependency, record in the pull request why it passes each of these
  (a new dependency also needs human sign-off — AGENTS.md › Security and human approval):
  - **Need** — why a small hand-written type, the Swift standard library, or Foundation
    cannot do the job
  - **Continuity** — recent releases, and more than one maintainer or an organization
    behind it
  - **License** — in the allow-list below, which `.github/workflows/dependency-review.yml`
    enforces
  - **Weight** — the direct and transitive package count after `swift package resolve`
  - **Build-time code** — whether it ships a binary target or a build/command plugin (code
    that runs at build time); either needs explicit human approval
  - **Platforms** — its platform floor is at or below this package's `.macOS(.v14)`
    (`platforms:` in `Packages/MyAppKit/Package.swift`)
  - **Advisories** — no open security advisory against the version being added
- Allowed licenses (SPDX): MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, Zlib.
  `.github/workflows/dependency-review.yml` enforces this exact list (`allow-licenses`) on
  every pull request — change both together; a per-package exception goes in its
  `allow-dependencies-licenses` with a comment giving the reason
- `Package.resolved` MUST be committed alongside any dependency change

## Version Requirements

- Declare a dependency with `.upToNextMajor(from:)` by default: the committed
  `Package.resolved` pins the exact version, so a range plus the resolved file reproduces
  the build
- Add or bump one by editing `Package.swift` and running `swift package resolve` (or
  `swift package update <Name>`) inside `Packages/MyAppKit` — never hand-edit
  `Package.resolved`: a hand-written entry states a revision nobody verified
- Verify with `just check`

## Gates

- NEVER lower the coverage floor (currently 80% on MyAppCore)
- NEVER remove SwiftLint rules without explicit user approval

## Project Generation

- `project.yml` is the source of truth; `MyApp.xcodeproj` is generated and gitignored —
  never hand-edit or commit it
- After changing `project.yml`, run `just generate` and build to verify

## Toolchain Pinning

- `.xcode-version` is the single source of truth for the CI Xcode pin (every macOS job
  derives `DEVELOPER_DIR` from it); CLI tools are pinned in `mise.toml`
- Bump pins deliberately (roughly monthly), one commit per bump, after `just check` passes locally
- Dependabot's `cooldown.default-days: 7` delays update PRs for SwiftPM and Actions; note that
  SwiftPM itself has no resolver-level cooldown (unlike uv's `exclude-newer`), so fresh installs
  are only protected by the committed `Package.resolved`
