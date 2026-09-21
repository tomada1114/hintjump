---
paths:
  - "project.yml"
  - "Packages/**/Package.swift"
  - "mise.toml"
  - ".swiftlint.yml"
  - ".swiftformat"
  - "scripts/coverage.sh"
---

## Dependency Policy

- The template ships with ZERO package dependencies — keep it that way unless the app truly needs one
- Before adding a dependency: verify active maintenance, a permissive license, and minimal
  transitive dependencies
- Allowed licenses (SPDX): MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, Zlib.
  `.github/workflows/dependency-review.yml` enforces this exact list (`allow-licenses`) on
  every pull request — change both together; a per-package exception goes in its
  `allow-dependencies-licenses` with a comment giving the reason
- `Package.resolved` MUST be committed alongside any dependency change
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
