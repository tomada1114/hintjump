# my-app

[![CI](https://github.com/your-username/my-app/actions/workflows/ci.yml/badge.svg)](https://github.com/your-username/my-app/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/your-username/my-app/badge)](https://scorecard.dev/viewer/?uri=github.com/your-username/my-app)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A strict, supply-chain-hardened GitHub template for open-source macOS apps.
It ships as a working counter app: XcodeGen project, thin app shell over a
local Swift package, Swift Testing suite with an enforced coverage floor, an
XCUITest launch guarantee, and hardened CI — all from the first commit.

Most popular OSS macOS apps ship without CI-gated tests, SECURITY.md,
Dependabot, or pinned actions. This template starts with all of them.

**Starting your own app from this template?** Jump to
[Using This Template](#using-this-template).

## Quickstart

Prerequisites: Xcode 26.5+, [mise](https://mise.jdx.dev/), and
[Just](https://just.systems) (`brew install mise just`).

```bash
git clone https://github.com/your-username/my-app.git
cd my-app
mise trust     # approve mise.toml once — mise refuses untrusted configs
just install   # pinned tools via mise + git hooks + xcodegen generate
just check     # format → lint → script tests → test (80% floor) → build
open MyApp.xcodeproj
```

## Design Philosophy

Every choice in this template has a reason. If you disagree with a decision,
you know exactly what to change and why it was there in the first place.

### Why XcodeGen with a gitignored `.xcodeproj`?

`project.yml` is declarative, diffable, and safely editable by both humans and
AI agents; a raw `pbxproj` is a UUID graph that merge conflicts and agents can
silently corrupt. The generated project is treated like a lockfile-derived
artifact: regenerate, never hand-edit. Trade-off: XcodeGen is a third-party
tool with its own bus factor — but the manifest is simple enough to migrate
away from if that ever matters.

### Why a thin app shell + local Swift package?

`App/` contains only the `@main` entry point and resources. Everything real
lives in `Packages/MyAppKit`, so tests run with plain `swift test` — no
simulator, no signing, no Xcode project required. Precedent: pointfreeco's
isowords.

### Why the Core/UI split and a coverage floor on Core only?

`MyAppCore` holds all logic and never imports SwiftUI, AppKit, UIKit, or Cocoa
(a lint rule and a test both enforce it); `MyAppUI` holds thin
views. The 80% line-coverage floor applies to Core only — that is what makes a
strict numeric gate *honest* for a GUI app instead of an invitation to write
meaningless view tests. Note: Swift's llvm-cov has no dependable branch
metric, so the gate uses line coverage (a deliberate divergence from this
template's Python sibling, which gates on branch coverage).

### Why Swift Testing?

`@Test`, `#expect`, and parameterized `@Test(arguments:)` are the modern
default shipped with the toolchain. XCTest appears exactly once — in the
XCUITest launch target, because Apple has not ported UI automation to Swift
Testing.

### Why zero dependencies?

An app template should not impose opinions about networking, persistence, or
update frameworks. You add what you need; docs/architecture.md lists vetted
suggestions (ViewInspector, swift-snapshot-testing, Sparkle) and when they
earn their place.

### Why Just?

One command — `just check` — runs the same gate locally that CI runs. Just has
cleaner syntax than Make and is a task runner, not a build system, which is
exactly what an Xcode project needs. Every recipe also works without Just (see
CONTRIBUTING.md).

### Why AGENTS.md and .claude/rules/?

AI-assisted development is the norm, not the exception. `AGENTS.md` and
path-scoped rules give LLMs the project's standards, architecture, and hard
prohibitions (never lower the coverage floor, never disable safety lint
rules) — reducing review cycles.

### Why secret-gated notarization?

The release workflow always produces a DMG; when Developer ID secrets are
configured it signs, notarizes, and staples, otherwise it ad-hoc signs and
says so loudly. The template works on day one without an Apple Developer
Program membership, and upgrades to fully trusted distribution by adding
secrets — no workflow edits. See docs/distribution.md.

## Using This Template

1. Click **"Use this template"** on GitHub and clone your new repository
   (the bootstrap script enumerates files with `git ls-files`, so it needs a
   git checkout — a ZIP download must be `git init`-ed first)
2. Run the bootstrap script to rename everything:

   ```bash
   scripts/bootstrap.sh CoolApp \
     --bundle-id-prefix io.example --github-user janedoe \
     --author "Jane Doe" --email jane@example.com
   ```

   This replaces `MyApp` (and `MyAppKit`/`MyAppCore`/`MyAppUI`), `my-app`,
   `com.example`, `your-username`, `Your Name`, and `you@example.com` across
   all tracked files, renames the matching paths, and regenerates the Xcode
   project. Omitted optional arguments leave their placeholders as-is.
3. Verify the rename: `just install && just check`
4. Update `README.md` (this file), `SECURITY.md`, `AGENTS.md`, and
   `CODE_OF_CONDUCT.md` for your app (the conduct-reporting contact stays
   `you@example.com` if `--email` was omitted, so check it), and review
   `LICENSE`'s copyright line (`CHANGELOG.md` is reset automatically)
5. Replace the counter placeholder in `Packages/<YourApp>Kit` with real code —
   keep the Core/UI split and the tests
6. For signed releases, add the secrets listed in docs/distribution.md

To find any placeholders the script left untouched (the pattern uses `.`
wildcards so the rename cannot rewrite this very command into your new names):

```bash
rg -i "my.?app|com\.example|your.username|Your.Name|you@example"
```

### Keeping up with template updates

A repository generated from a GitHub template has no upstream link — the files
are copied once. To pull later template improvements (CI hardening, lint-rule
bumps, workflow fixes) into your app:

```bash
git remote add template https://github.com/tomada1114/macos-app-template.git
git fetch template
git cherry-pick <sha>    # or: git merge template/main --allow-unrelated-histories
```

Cherry-picking narrowly scoped commits is usually cleaner than a full merge:
the bootstrap rename means most template commits touch files whose names and
contents differ in your repository. Treat the template as a starting point,
not a dependency — adopt the changes that earn their place.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for full setup instructions.

```bash
just install
just check
```

The first local `just uitest` run may prompt for Accessibility permission
(System Settings → Privacy & Security); CI runners are pre-provisioned and
run it on every push.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Distribution & Signing](docs/distribution.md)
- [Adding iOS Later](docs/adding-ios.md)

## License

[MIT](LICENSE)
