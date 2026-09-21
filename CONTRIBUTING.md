# Contributing

Thank you for considering a contribution! This document explains how to set up
your development environment and submit changes.

## Prerequisites

Install these tools:

- [Xcode 26.5+](https://developer.apple.com/xcode/) (CI pins the exact version in
  `.xcode-version`)
- [mise](https://mise.jdx.dev/) — provides the pinned CLI tools from `mise.toml`
- [Just](https://just.systems/man/en/installation.html) (optional — you can run
  the underlying commands directly)

Then:

```bash
mise trust     # approve mise.toml (asked once per fresh clone)
just install
```

## Development Workflow

```bash
# Format
just fmt

# Lint (scripts/lint.sh: swiftformat --lint + swiftlint --strict + shellcheck + actionlint + typos)
just lint

# Run the plain-bash tests for scripts/
just test-scripts

# Run tests with the coverage floor
just test

# Build the app
just build

# Build (Debug) and launch it, left running until you quit it
just run

# Launch guarantee (Release build + alive check)
just smoke

# Run everything (format → lint → script tests → test → build)
just check
```

**Without Just**, run the equivalent commands:

```bash
mise install
git config core.hooksPath .githooks   # pre-commit lint gate (just install does this)
scripts/verify-hooks.sh               # confirm the hooks are installed and executable
mise exec -- swiftformat .
mise exec -- scripts/lint.sh
scripts/tests/run.sh
scripts/coverage.sh
mise exec -- xcodegen generate
xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug -derivedDataPath build/dev-derived-data build
open build/dev-derived-data/Build/Products/Debug/MyApp.app
rm -rf build/LaunchUITests.xcresult
xcodebuild test -project MyApp.xcodeproj -scheme MyApp -destination 'platform=macOS' -derivedDataPath build/dev-derived-data -resultBundlePath build/LaunchUITests.xcresult
scripts/smoke_launch.sh
scripts/sync-agents.sh           # after editing .agents/skills/ (just agents-sync)
scripts/sync-agents.sh --check   # just agents-check
scripts/sync-labels.sh           # just labels — writes labels to the GitHub repo gh is pointed at
```

## Pull Request Process

1. Fork the repository and create a branch from `main`
2. Make your changes
3. Ensure `just check` passes
4. Write or update tests for your changes
5. Open a pull request using the PR template

### Code Standards

- New logic lives in `MyAppCore` with Swift Testing coverage (happy + error path)
- SwiftLint strict and SwiftFormat must pass with no warnings
- Maintain or improve the 80% line-coverage floor on `MyAppCore`
- Public API carries `///` doc comments that explain *why*

### Commit Messages

Use Conventional Commits for both commits and PR titles:

```
<type>(<optional-scope>): <short summary>
```

Examples:

- `feat: add JSON export support`
- `fix(ui): handle window restoration`
- `docs: update installation guide`

Recommended types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`,
`perf`, `build`, `deps` (dependency bumps).

### Changelog Policy

`CHANGELOG.md` (in [Keep a Changelog](https://keepachangelog.com/) format) is
the canonical, human-curated record of user-facing changes. Add an entry
under `[Unreleased]` for any user-facing change in the same PR that makes it.

GitHub's auto-generated release notes (via `.github/release.yml` categories)
are supplementary — useful for a quick PR-by-PR diff, but `CHANGELOG.md` is
what users should read to understand what changed in a release.

## Getting Help

If something is unclear, open an issue. We're happy to help you get started.
