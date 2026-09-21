#!/usr/bin/env bash
# Verify that this repository's pre-commit hook is really in force: that git
# resolves the hooks directory to the tracked .githooks/, and that
# .githooks/pre-commit is executable.
#
#   scripts/verify-hooks.sh
#
# `just install` sets `core.hooksPath .githooks`, but nothing checked afterward
# that the config stuck or that the hook file kept its executable bit — a clone
# whose hook silently failed to install looked identical to one that succeeded.
# This runs at the end of `just install` and as the first step of `just check`,
# closing that gap there; it does not close it everywhere (AGENTS.md's
# Enforcement layers names it as narrowed): a contributor who runs neither still
# commits without hooks, and CI remains the backstop.
#
# The hooks directory is resolved with `git rev-parse --git-path hooks` rather
# than assuming `.git/hooks`, so both `core.hooksPath` and a linked worktree's
# shared hooks directory are honored. Both sides of the comparison are reduced
# to a physical path (`cd DIR && pwd -P`), so a relative answer (resolved
# against the current directory, the same way git resolves it) and a symlinked
# temp root (`/var` -> `/private/var` on macOS) never produce a false mismatch.
#
# Skips (exit 0, one-line notice on stdout), checked in this order: the
# ALLOW_MISSING_GIT_HOOKS opt-out is truthy; CI is truthy (unset, empty, "0",
# and "false" all count as off); or this directory is not inside a git work
# tree. Git work tree: required to check anything; a check that is meaningless
# outside one skips rather than fails.
#
# Errors (each followed by Expected:/Actual:/Next: lines, exit 1; Next: always
# ends with the ALLOW_MISSING_GIT_HOOKS opt-out sentence):
#   ERR_HOOKS_NOT_INSTALLED    git does not resolve the hooks directory to .githooks/
#   ERR_HOOKS_NOT_EXECUTABLE   .githooks/pre-commit is missing or not executable
set -euo pipefail

OPT_OUT="ALLOW_MISSING_GIT_HOOKS"
OPT_OUT_SENTENCE="Or, if this environment cannot have git hooks, set ${OPT_OUT}=1."

# is_truthy VALUE — unset, empty, "0", and "false" all read as off; anything
# else reads as on. Matches the truthiness CI providers use for their own flag.
is_truthy() {
    case "${1-}" in
        "" | 0 | false) return 1 ;;
        *) return 0 ;;
    esac
}

if is_truthy "${ALLOW_MISSING_GIT_HOOKS-}"; then
    echo "verify-hooks: ${OPT_OUT} is set; not checking the pre-commit hook."
    exit 0
fi
if is_truthy "${CI-}"; then
    echo "verify-hooks: CI is set; not checking the pre-commit hook."
    exit 0
fi
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]; then
    echo "verify-hooks: not inside a git work tree; not checking the pre-commit hook."
    exit 0
fi

fail() { # fail <code> <what failed> <expected> <actual> <next>
    echo "$1: $2" >&2
    echo "Expected: $3" >&2
    echo "Actual: $4" >&2
    echo "Next: $5 ${OPT_OUT_SENTENCE}" >&2
    exit 1
}

TOPLEVEL=$(git rev-parse --show-toplevel)
EXPECTED_DIR="${TOPLEVEL}/.githooks"

# --git-path answers relative to the current directory when core.hooksPath is a
# relative path (an ordinary checkout), and absolutely when it is set to an
# absolute path or resolved through a linked worktree's shared common
# directory. Resolving a relative answer against $(pwd) covers all three: it is
# the same directory git itself resolved the answer relative to.
HOOKS_PATH_RAW=$(git rev-parse --git-path hooks)
case "${HOOKS_PATH_RAW}" in
    /*) HOOKS_DIR="${HOOKS_PATH_RAW}" ;;
    *) HOOKS_DIR="$(pwd)/${HOOKS_PATH_RAW}" ;;
esac

RESOLVED_HOOKS_DIR=""
[ -d "${HOOKS_DIR}" ] && RESOLVED_HOOKS_DIR=$(cd "${HOOKS_DIR}" && pwd -P)
RESOLVED_EXPECTED_DIR=""
[ -d "${EXPECTED_DIR}" ] && RESOLVED_EXPECTED_DIR=$(cd "${EXPECTED_DIR}" && pwd -P)

if [ -z "${RESOLVED_HOOKS_DIR}" ] || [ "${RESOLVED_HOOKS_DIR}" != "${RESOLVED_EXPECTED_DIR}" ]; then
    if [ -z "${RESOLVED_HOOKS_DIR}" ]; then
        ACTUAL="\`git rev-parse --git-path hooks\` resolves to ${HOOKS_DIR}, which does not exist"
    else
        ACTUAL="\`git rev-parse --git-path hooks\` resolves to ${RESOLVED_HOOKS_DIR}"
    fi
    fail ERR_HOOKS_NOT_INSTALLED \
        "git does not resolve the hooks directory to ${EXPECTED_DIR}" \
        "git runs hooks from ${EXPECTED_DIR} (core.hooksPath .githooks)" \
        "${ACTUAL}" \
        "run \`just install\`, or \`git config core.hooksPath .githooks\`."
fi

HOOK_PATH="${EXPECTED_DIR}/pre-commit"
if [ ! -f "${HOOK_PATH}" ] || [ ! -x "${HOOK_PATH}" ]; then
    if [ ! -e "${HOOK_PATH}" ]; then
        ACTUAL="no file at .githooks/pre-commit"
    elif [ ! -f "${HOOK_PATH}" ]; then
        ACTUAL=".githooks/pre-commit exists but is not a regular file"
    else
        ACTUAL=".githooks/pre-commit exists but is not executable"
    fi
    fail ERR_HOOKS_NOT_EXECUTABLE \
        ".githooks/pre-commit is missing or not executable" \
        "an executable .githooks/pre-commit" \
        "${ACTUAL}" \
        "run \`git checkout -- .githooks/pre-commit && chmod +x .githooks/pre-commit\`, or re-run \`just install\`."
fi

echo "verify-hooks: .githooks/pre-commit is installed and executable."
