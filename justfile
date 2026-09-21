# Development task runner — requires Just (https://just.systems)
# All commands also work without Just by running the underlying commands directly
# (see CONTRIBUTING.md). Tools come from mise (mise.toml pins the versions).

# Show available recipes
default:
    @just --list

# Install pinned tools, git hooks, and generate the Xcode project
install:
    mise install
    if git rev-parse --git-dir >/dev/null 2>&1; then git config core.hooksPath .githooks; else echo "Skipping git hook installation (not a Git repository)."; fi
    mise exec -- xcodegen generate
    @if command -v xcodebuild >/dev/null 2>&1; then xcode_local="$(xcodebuild -version | head -n1 | awk '{print $2}')"; xcode_pinned="$(cat .xcode-version)"; if [ "$xcode_local" != "$xcode_pinned" ]; then echo "warning: local Xcode $xcode_local differs from the CI-pinned $xcode_pinned — results may diverge from CI"; fi; fi
    just verify-hooks

# Regenerate MyApp.xcodeproj from project.yml
generate:
    mise exec -- xcodegen generate

# Format code
fmt:
    mise exec -- swiftformat .

# Format and auto-fix SwiftLint violations, then run the full lint check: some
# violations have no safe auto-fix, and the check reports what still needs a hand edit
fix:
    mise exec -- swiftformat .
    mise exec -- swiftlint lint --fix --quiet
    just lint

# Run formatters and linters in check mode (swiftformat, swiftlint, shellcheck, actionlint, typos)
lint:
    mise exec -- scripts/lint.sh

# Verify the git hooks are installed and executable (skips under CI or ALLOW_MISSING_GIT_HOOKS)
verify-hooks:
    scripts/verify-hooks.sh

# Run the plain-bash tests for the scripts under scripts/ (through mise: the
# scripts/checks/ tests call the pinned `just`)
test-scripts:
    mise exec -- scripts/tests/run.sh

# Re-assert the harness's claims about itself: recipe names in AGENTS.md, workflow
# pins and permissions, skill frontmatter, and the Skills index (scripts/checks/)
check-harness:
    mise exec -- scripts/checks/run-all.sh

# Run tests with the 80% line-coverage floor on MyAppCore
test:
    scripts/coverage.sh

# Run only the tests matching FILTER (swift test --filter), with no coverage floor —
# for fast local iteration; `just test` is still the gate
test-fast filter:
    cd Packages/MyAppKit && swift test --filter '{{filter}}'

# Build the app (Debug)
build:
    mise exec -- xcodegen generate
    set -o pipefail && xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug -derivedDataPath build/dev-derived-data build | mise exec -- xcbeautify --quiet

# Build (Debug) and launch the app, left running until you quit it
run: build
    open build/dev-derived-data/Build/Products/Debug/MyApp.app

# Run the XCUITest launch test (may prompt for Accessibility permission on first local run)
uitest:
    mise exec -- xcodegen generate
    rm -rf build/LaunchUITests.xcresult
    set -o pipefail && xcodebuild test -project MyApp.xcodeproj -scheme MyApp -destination 'platform=macOS' -derivedDataPath build/dev-derived-data -resultBundlePath build/LaunchUITests.xcresult | mise exec -- xcbeautify

# Build Release and assert the app launches and stays alive
smoke:
    scripts/smoke_launch.sh

# Run all checks: verify hooks, format, lint, script tests, harness checks, test, build
# (CI's app job adds uitest + smoke)
check: verify-hooks fmt lint test-scripts check-harness test build

# Regenerate the .claude/skills/ mirror from .agents/skills/ (run after any skill edit)
agents-sync:
    scripts/sync-agents.sh

# Fail if .claude/skills/ is not byte-identical to .agents/skills/ (writes nothing)
agents-check:
    scripts/sync-agents.sh --check

# Remove build artifacts and the generated project
clean:
    rm -rf build Packages/MyAppKit/.build MyApp.xcodeproj

# Create or update this repository's GitHub labels from .github/labels.yml
# (never deletes). Requires `gh`, authenticated against this repository: it is
# not a mise tool (see mise.toml), so it comes from your own PATH, not `mise exec --`.
labels:
    scripts/sync-labels.sh

# Create or update the "main" branch ruleset from .github/rulesets/main.json
# (admin-only: applying a ruleset needs repository admin permissions). Requires
# `gh`, authenticated against this repository: like `labels` above, it is not a
# mise tool, so it comes from your own PATH, not `mise exec --`.
ruleset:
    scripts/apply-ruleset.sh
