#!/usr/bin/env bash
# The one lint command: `just lint`, the pre-commit hook, and CI's lint job all call it.
#
#   scripts/lint.sh                      lint the whole repository
#   scripts/lint.sh --staged-tree DIR    lint only the Swift files exported into DIR
#
# Whole repository: swiftformat --lint, swiftlint --strict, shellcheck over every
# tracked shell script, actionlint, and typos. --staged-tree: swiftformat and
# swiftlint only, against DIR. Every check runs even if an earlier one fails; the
# script exits 1 if any failed.
#
# Tools are called by bare name, never through `mise exec --`: that would
# auto-install every tool in mise.toml, including the macOS-only ones CI's Linux
# lint job deliberately skips. The caller puts the tools on PATH — locally
# `mise exec -- scripts/lint.sh` (what `just lint` runs), in CI jdx/mise-action.
#
# Errors:
#   ERR_LINT_USAGE         unknown argument, or a --staged-tree DIR that does not exist
#   ERR_LINT_TOOL_MISSING  a tool this mode needs is not on PATH
set -euo pipefail

USAGE='usage: scripts/lint.sh [--staged-tree DIR]'

usage_error() {
    echo "ERR_LINT_USAGE: $1" >&2
    echo "${USAGE}" >&2
    exit 1
}

STAGED_TREE=""
case $# in
    0) ;;
    2)
        [ "$1" = "--staged-tree" ] || usage_error "unknown argument '$1'"
        [ -d "$2" ] || usage_error "--staged-tree directory '$2' does not exist"
        # Resolve before the cd below so a relative DIR keeps pointing at the same place.
        STAGED_TREE=$(cd "$2" && pwd)
        ;;
    *) usage_error "unexpected arguments: $*" ;;
esac

cd "$(dirname "$0")/.."

if [ -n "${STAGED_TREE}" ]; then
    REQUIRED_TOOLS=(swiftformat swiftlint)
else
    REQUIRED_TOOLS=(git swiftformat swiftlint shellcheck actionlint typos)
fi
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "ERR_LINT_TOOL_MISSING: '${tool}' is not on PATH" >&2
        echo "Next: run it through mise — \`mise exec -- scripts/lint.sh\` or \`just lint\`" >&2
        exit 1
    fi
done

FAILED=()
run() {
    echo "==> $*"
    if ! "$@"; then
        FAILED+=("$1")
    fi
}

if [ -n "${STAGED_TREE}" ]; then
    run swiftformat --lint --config .swiftformat "${STAGED_TREE}"
    run swiftlint lint --strict --quiet --config .swiftlint.yml "${STAGED_TREE}"
else
    # Every tracked *.sh at any depth, so a script added later is covered without
    # editing this list. set -e cannot see a failure inside the process
    # substitution, so the work-tree check runs first and fails loudly on its own.
    git rev-parse --is-inside-work-tree >/dev/null
    SHELL_FILES=(.githooks/pre-commit)
    while IFS= read -r -d '' file; do
        SHELL_FILES+=("${file}")
    done < <(git ls-files -z -- '*.sh')

    run swiftformat --lint .
    run swiftlint lint --strict --quiet
    run shellcheck "${SHELL_FILES[@]}"
    # With shellcheck on PATH, actionlint also lints workflow run: blocks.
    run actionlint
    # typos reads typos.toml from the repository root automatically.
    run typos
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "lint: failed: ${FAILED[*]}" >&2
    exit 1
fi
echo "lint: all checks passed"
