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

# Regenerate MyApp.xcodeproj from project.yml
generate:
    mise exec -- xcodegen generate

# Format code
fmt:
    mise exec -- swiftformat .

# Run formatters and linters in check mode (swiftformat, swiftlint, shellcheck, actionlint, typos)
lint:
    mise exec -- scripts/lint.sh

# Run the plain-bash tests for the scripts under scripts/
test-scripts:
    scripts/tests/run.sh

# Run tests with the 80% line-coverage floor on MyAppCore
test:
    scripts/coverage.sh

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

# Run all checks: format, lint, script tests, test, build (CI's app job adds uitest + smoke)
check: fmt lint test-scripts test build

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
