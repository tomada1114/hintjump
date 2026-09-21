#!/usr/bin/env bash
# Tests for scripts/verify-hooks.sh. Every case builds its own throwaway git
# repository with make_temp_repo and a copy of the script, so the real checkout
# is never read or written. CI is unset for the whole file (this file itself
# may run under CI=true — GitHub Actions sets it for every job — and most cases
# need to see the script's real, non-skipped behavior); the two cases that
# exercise the CI branch pass it explicitly.
set -euo pipefail
# shellcheck source=scripts/tests/lib.sh
. "$(dirname "$0")/lib.sh"
trap cleanup_temp EXIT

unset CI ALLOW_MISSING_GIT_HOOKS

VERIFY_SRC="${REPO_ROOT}/scripts/verify-hooks.sh"

# Prints a repo with core.hooksPath wired to .githooks and an installed,
# executable pre-commit hook — the passing starting point for each case.
make_installed_repo() {
    local repo
    repo=$(make_temp_repo)
    mkdir "${repo}/.githooks"
    printf '#!/bin/sh\nexit 0\n' >"${repo}/.githooks/pre-commit"
    chmod +x "${repo}/.githooks/pre-commit"
    git -C "${repo}" add .githooks
    git -C "${repo}" commit -q -m "add hook"
    git -C "${repo}" config core.hooksPath .githooks
    echo "${repo}"
}

case_installed_passes() {
    local repo
    repo=$(make_installed_repo)
    cd "${repo}"
    capture "${BASH}" "${VERIFY_SRC}"
    assert_exit 0
    assert_stdout_contains "installed and executable"
}

case_hooks_path_unset_fails() {
    local repo
    repo=$(make_installed_repo)
    git -C "${repo}" config --unset core.hooksPath
    cd "${repo}"
    capture "${BASH}" "${VERIFY_SRC}"
    assert_exit 1
    assert_stderr_contains "ERR_HOOKS_NOT_INSTALLED"
    assert_stderr_contains "Expected:"
    assert_stderr_contains "Actual:"
    assert_stderr_contains "Next:"
    assert_stderr_contains "Or, if this environment cannot have git hooks, set ALLOW_MISSING_GIT_HOOKS=1."
    head -n 1 "${CASE_DIR}/stderr" | grep -q '^ERR_HOOKS_NOT_INSTALLED: ' || _fail "first stderr line is not ERR_HOOKS_NOT_INSTALLED"
}

case_hook_missing_fails() {
    local repo
    repo=$(make_installed_repo)
    rm "${repo}/.githooks/pre-commit"
    cd "${repo}"
    capture "${BASH}" "${VERIFY_SRC}"
    assert_exit 1
    assert_stderr_contains "ERR_HOOKS_NOT_EXECUTABLE"
    assert_stderr_contains "Or, if this environment cannot have git hooks, set ALLOW_MISSING_GIT_HOOKS=1."
}

case_hook_not_executable_fails() {
    local repo
    repo=$(make_installed_repo)
    chmod -x "${repo}/.githooks/pre-commit"
    cd "${repo}"
    capture "${BASH}" "${VERIFY_SRC}"
    assert_exit 1
    assert_stderr_contains "ERR_HOOKS_NOT_EXECUTABLE"
    assert_stderr_contains "Or, if this environment cannot have git hooks, set ALLOW_MISSING_GIT_HOOKS=1."
}

case_opt_out_skips() {
    local repo
    repo=$(make_installed_repo)
    git -C "${repo}" config --unset core.hooksPath
    cd "${repo}"
    capture env ALLOW_MISSING_GIT_HOOKS=1 "${BASH}" "${VERIFY_SRC}"
    assert_exit 0
    assert_stdout_contains "ALLOW_MISSING_GIT_HOOKS is set"
}

case_ci_true_skips() {
    local repo
    repo=$(make_installed_repo)
    git -C "${repo}" config --unset core.hooksPath
    cd "${repo}"
    capture env CI=true "${BASH}" "${VERIFY_SRC}"
    assert_exit 0
    assert_stdout_contains "CI is set"
}

# CI's own off spelling ("0") must not read as "on", the same truthiness the
# opt-out and CI checks share — otherwise `CI=0` would silently drop the check.
case_ci_zero_still_fails() {
    local repo
    repo=$(make_installed_repo)
    git -C "${repo}" config --unset core.hooksPath
    cd "${repo}"
    capture env CI=0 "${BASH}" "${VERIFY_SRC}"
    assert_exit 1
    assert_stderr_contains "ERR_HOOKS_NOT_INSTALLED"
}

case_outside_work_tree_skips() {
    local dir
    dir=$(make_temp_dir)
    cd "${dir}"
    capture env GIT_CEILING_DIRECTORIES="${dir}" "${BASH}" "${VERIFY_SRC}"
    assert_exit 0
    assert_stdout_contains "not inside a git work tree"
}

# A linked worktree of an installed repo also passes: .githooks is tracked, so
# it is checked out into the worktree too, and the hooks directory the shared
# common config resolves to must still match this worktree's .githooks.
case_linked_worktree_passes() {
    local repo wt
    repo=$(make_installed_repo)
    wt="$(dirname "${repo}")/wt"
    git -C "${repo}" worktree add -q -b wt-branch "${wt}"
    cd "${wt}"
    capture "${BASH}" "${VERIFY_SRC}"
    assert_exit 0
    assert_stdout_contains "installed and executable"
}

run_case "hooks installed and executable: exit 0" case_installed_passes
run_case "core.hooksPath unset fails ERR_HOOKS_NOT_INSTALLED" case_hooks_path_unset_fails
run_case "missing pre-commit file fails ERR_HOOKS_NOT_EXECUTABLE" case_hook_missing_fails
run_case "non-executable pre-commit file fails ERR_HOOKS_NOT_EXECUTABLE" case_hook_not_executable_fails
run_case "ALLOW_MISSING_GIT_HOOKS=1 skips even with hooks broken" case_opt_out_skips
run_case "CI=true skips even with hooks broken" case_ci_true_skips
run_case "CI=0 with hooks unset still fails" case_ci_zero_still_fails
run_case "outside a git work tree skips" case_outside_work_tree_skips
run_case "a linked worktree of an installed repo exits 0" case_linked_worktree_passes
finish
