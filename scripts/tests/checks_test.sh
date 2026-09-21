#!/usr/bin/env bash
# Tests for the harness-conformance checks under scripts/checks/ (their sourced
# scripts/checks/lib.sh included) and their runner, scripts/checks/run-all.sh.
# Every case builds its own fixture tree in a temp directory with make_fixture and
# points the check at it with --root, so the real checkout is never read or
# written. Each failure mode gets its own case, and each asserts the specific error
# code and the offending name or line, so a check weakened to always pass (or to
# skip the thing it checks) fails here. just-recipes-exist.sh runs the real `just`
# (a mise tool): run this file through `mise exec --`, or with just on PATH.
set -euo pipefail
# shellcheck source=scripts/tests/lib.sh
. "$(dirname "$0")/lib.sh"
trap cleanup_temp EXIT

CHECKS="${REPO_ROOT}/scripts/checks"
SHA="9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0"
# A literal backtick, so Markdown code spans can be written in double quotes.
BT='`'

if ! command -v just >/dev/null 2>&1; then
    echo "ERR_TESTS_TOOL_MISSING: 'just' is not on PATH" >&2
    echo "Expected: just (pinned in mise.toml) on PATH for just-recipes-exist.sh's cases" >&2
    echo "Actual: \`command -v just\` found nothing" >&2
    echo "Next: run \`mise exec -- scripts/tests/run.sh\`, or \`just test-scripts\`" >&2
    exit 1
fi

# write_skill ROOT NAME — a well-formed .agents/skills/NAME/SKILL.md.
write_skill() {
    mkdir -p "$1/.agents/skills/$2"
    cat >"$1/.agents/skills/$2/SKILL.md" <<EOF
---
name: $2
description: >
  Covers the $2 fixture skill. Use when testing the harness checks.
---

# $2
EOF
}

# Prints the path of a fixture tree every check passes on. It deliberately holds
# the near misses each check must not flag: a `just --list` and a `just <recipe>`
# placeholder, `just` in prose outside backticks, a local `uses:`, a quoted pin,
# a `### Rules` table after the Skills table, and a composite action.
make_fixture() {
    local root
    root=$(make_temp_dir)
    cat >"${root}/justfile" <<'EOF'
default:
    @just --list

generate:
    echo generate

build:
    echo build

check: build
    echo check
EOF
    cat >"${root}/AGENTS.md" <<'EOF'
# Project Guide

## Quick Reference

```bash
just generate  # Regenerate
just check     # Everything
```

Run `just --list` to see recipes, then `just generate && just build`. A
`just <recipe>` placeholder names nothing, and this is just prose: just bogus.

## Skills

| Skill | Load it when you are working on |
|---|---|
| `alpha` | the first thing |
| `beta` | the second thing |

### Rules

| Rule | Loads when you touch |
|---|---|
| `.claude/rules/project.md` | `project.yml` |

## Enforcement layers

| Layer | Fires on |
|---|---|
| `gamma` | never |
EOF
    write_skill "${root}" alpha
    write_skill "${root}" beta
    mkdir -p "${root}/.github/workflows" "${root}/.github/actions/setup"
    cat >"${root}/.github/workflows/ci.yml" <<EOF
name: CI

on:
  pull_request:

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@${SHA} # v7.0.0
      - uses: ./.github/actions/setup
      - name: Upload
        uses: "github/codeql-action/upload-sarif@${SHA}" # v4.36.3
EOF
    cat >"${root}/.github/workflows/release.yml" <<EOF
name: Release
on:
  push:
permissions: {}
jobs:
  build:
    permissions:
      contents: write
    runs-on: ubuntu-latest
    steps:
      - uses: jdx/mise-action@${SHA} # v4.2.0
EOF
    cat >"${root}/.github/actions/setup/action.yml" <<EOF
name: Setup
runs:
  using: composite
  steps:
    - uses: actions/cache@${SHA} # v4.2.3
EOF
    echo "${root}"
}

# first_stderr_is CODE — the failure contract: the first stderr line is `CODE: …`.
first_stderr_is() {
    head -n 1 "${CASE_DIR}/stderr" | grep -q "^$1: " || _fail "first stderr line is not $1"
}

assert_contract() {
    first_stderr_is "$1"
    assert_stderr_contains "Expected:"
    assert_stderr_contains "Actual:"
    assert_stderr_contains "Next:"
}

# --- run-all.sh ---------------------------------------------------------------

case_run_all_passes() {
    local root
    root=$(make_fixture)
    capture "${BASH}" "${CHECKS}/run-all.sh" --root "${root}"
    assert_exit 0
    assert_stdout_contains "harness checks: 4 check(s) passed"
}

case_run_all_reports_every_failure() {
    local root
    root=$(make_fixture)
    echo "Then run ${BT}just deploy${BT}." >>"${root}/AGENTS.md"
    sed '/^permissions:/d; /^  contents: read/d' "${root}/.github/workflows/ci.yml" >"${root}/ci.tmp"
    mv "${root}/ci.tmp" "${root}/.github/workflows/ci.yml"
    capture "${BASH}" "${CHECKS}/run-all.sh" --root "${root}"
    assert_exit 1
    assert_stderr_contains "ERR_CHECK_RECIPE_MISSING"
    assert_stderr_contains "ERR_CHECK_WORKFLOW_PERMISSIONS"
    assert_stderr_contains "ERR_CHECKS_FAILED: 2 of 4 harness check(s) failed: just-recipes-exist.sh workflow-pins-and-permissions.sh"
    assert_stderr_not_contains "skills-frontmatter.sh" "a passing check named as failed"
    assert_stderr_not_contains "skills-index-complete.sh" "a passing check named as failed"
    assert_stdout_contains "==> scripts/checks/skills-index-complete.sh"
}

case_run_all_rejects_unknown_argument() {
    capture "${BASH}" "${CHECKS}/run-all.sh" --bogus
    assert_exit 1
    assert_contract ERR_CHECK_USAGE
}

case_check_rejects_missing_root() {
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${CASE_DIR}/nope"
    assert_exit 1
    assert_contract ERR_CHECK_USAGE
}

# --- just-recipes-exist.sh ----------------------------------------------------

case_recipes_pass() {
    local root
    root=$(make_fixture)
    capture "${BASH}" "${CHECKS}/just-recipes-exist.sh" --root "${root}"
    assert_exit 0
}

case_recipes_bogus_inline() {
    local root
    root=$(make_fixture)
    echo "Then run ${BT}just deploy${BT}." >>"${root}/AGENTS.md"
    capture "${BASH}" "${CHECKS}/just-recipes-exist.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_RECIPE_MISSING
    assert_stderr_contains "AGENTS.md:$(wc -l <"${root}/AGENTS.md" | tr -d ' '): \`just deploy\`"
}

case_recipes_bogus_second_in_chain() {
    local root
    root=$(make_fixture)
    echo "Run ${BT}just build && just deploy-later${BT}." >>"${root}/AGENTS.md"
    capture "${BASH}" "${CHECKS}/just-recipes-exist.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_RECIPE_MISSING
    assert_stderr_contains "no recipe named 'deploy-later'"
    assert_stderr_not_contains "no recipe named 'build'" "an existing recipe reported missing"
}

case_recipes_bogus_in_fenced_block() {
    local root
    root=$(make_fixture)
    printf '\n%sbash\njust release  # Ship it\n%s\n' "${BT}${BT}${BT}" "${BT}${BT}${BT}" >>"${root}/AGENTS.md"
    capture "${BASH}" "${CHECKS}/just-recipes-exist.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_RECIPE_MISSING
    assert_stderr_contains "no recipe named 'release'"
}

case_recipes_just_missing() {
    local root
    root=$(make_fixture)
    if [ -x /usr/bin/just ] || [ -x /bin/just ]; then
        echo "  skip: just is installed under /usr/bin or /bin" >&2
        return 0
    fi
    PATH="/usr/bin:/bin" capture "${BASH}" "${CHECKS}/just-recipes-exist.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_TOOL_MISSING
}

# --- workflow-pins-and-permissions.sh ----------------------------------------

case_workflows_pass() {
    local root
    root=$(make_fixture)
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 0
}

case_workflows_pass_without_actions_dir() {
    local root
    root=$(make_fixture)
    mv "${root}/.github/actions" "${CASE_DIR}/actions"
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 0
}

case_workflows_missing_permissions() {
    local root
    root=$(make_fixture)
    cat >"${root}/.github/workflows/lint.yml" <<EOF
name: Lint
on: push
jobs:
  lint:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@${SHA} # v7.0.0
EOF
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_WORKFLOW_PERMISSIONS
    assert_stderr_contains ".github/workflows/lint.yml: no top-level"
    assert_stderr_not_contains "ci.yml: no top-level" "a workflow with permissions reported"
}

case_workflows_tag_pin_in_workflow() {
    local root
    root=$(make_fixture)
    echo "      - uses: actions/setup-node@v4" >>"${root}/.github/workflows/ci.yml"
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_WORKFLOW_UNPINNED
    assert_stderr_contains ".github/workflows/ci.yml:$(wc -l <"${root}/.github/workflows/ci.yml" | tr -d ' '): actions/setup-node@v4"
}

case_workflows_tag_pin_in_composite_action() {
    local root
    root=$(make_fixture)
    echo "    - uses: actions/setup-python@v5 # v5.0.0" >>"${root}/.github/actions/setup/action.yml"
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_WORKFLOW_UNPINNED
    assert_stderr_contains ".github/actions/setup/action.yml:6: actions/setup-python@v5"
}

case_workflows_sha_without_version_comment() {
    local root
    root=$(make_fixture)
    echo "      - uses: actions/setup-go@${SHA}" >>"${root}/.github/workflows/ci.yml"
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_WORKFLOW_UNPINNED
    assert_stderr_contains "actions/setup-go@${SHA}"
}

case_workflows_short_sha() {
    local root
    root=$(make_fixture)
    echo "      - uses: actions/setup-go@9c091bb # v5.0.0" >>"${root}/.github/workflows/ci.yml"
    capture "${BASH}" "${CHECKS}/workflow-pins-and-permissions.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_WORKFLOW_UNPINNED
    assert_stderr_contains "actions/setup-go@9c091bb"
}

# --- skills-frontmatter.sh ----------------------------------------------------

case_frontmatter_pass() {
    local root
    root=$(make_fixture)
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 0
}

case_frontmatter_third_key() {
    local root
    root=$(make_fixture)
    { head -n 2 "${root}/.agents/skills/alpha/SKILL.md"; echo 'paths: "**/*.swift"'; tail -n +3 "${root}/.agents/skills/alpha/SKILL.md"; } >"${CASE_DIR}/x"
    mv "${CASE_DIR}/x" "${root}/.agents/skills/alpha/SKILL.md"
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_FRONTMATTER
    assert_stderr_contains ".agents/skills/alpha: unexpected key \`paths\`"
    assert_stderr_not_contains ".agents/skills/beta:" "a well-formed skill reported"
}

case_frontmatter_name_mismatch() {
    local root
    root=$(make_fixture)
    sed 's/^name: beta$/name: gamma/' "${root}/.agents/skills/beta/SKILL.md" >"${CASE_DIR}/x"
    mv "${CASE_DIR}/x" "${root}/.agents/skills/beta/SKILL.md"
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_FRONTMATTER
    assert_stderr_contains ".agents/skills/beta: \`name\` is \`gamma\`, but the directory is \`beta\`"
}

case_frontmatter_empty_description() {
    local root
    root=$(make_fixture)
    printf -- '---\nname: alpha\ndescription: >\n---\n\n# alpha\n' >"${root}/.agents/skills/alpha/SKILL.md"
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_FRONTMATTER
    assert_stderr_contains ".agents/skills/alpha: \`description\` is empty"
}

case_frontmatter_missing_block() {
    local root
    root=$(make_fixture)
    printf '# alpha\n\nname: alpha\n' >"${root}/.agents/skills/alpha/SKILL.md"
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_FRONTMATTER
    assert_stderr_contains ".agents/skills/alpha: does not start with a \`---\` frontmatter line"
}

case_frontmatter_unclosed_block() {
    local root
    root=$(make_fixture)
    printf -- '---\nname: alpha\ndescription: A skill.\n' >"${root}/.agents/skills/alpha/SKILL.md"
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_FRONTMATTER
    assert_stderr_contains ".agents/skills/alpha: frontmatter block is never closed"
}

case_frontmatter_missing_skill_file() {
    local root
    root=$(make_fixture)
    mkdir "${root}/.agents/skills/gamma"
    capture "${BASH}" "${CHECKS}/skills-frontmatter.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_FRONTMATTER
    assert_stderr_contains ".agents/skills/gamma: no SKILL.md"
}

# --- skills-index-complete.sh -------------------------------------------------

case_index_pass_ignores_rules_table() {
    local root
    root=$(make_fixture)
    capture "${BASH}" "${CHECKS}/skills-index-complete.sh" --root "${root}"
    assert_exit 0
    assert_stderr_not_contains ".claude/rules/project.md" "the ### Rules table read as skills"
}

case_index_directory_without_row() {
    local root
    root=$(make_fixture)
    write_skill "${root}" delta
    capture "${BASH}" "${CHECKS}/skills-index-complete.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_INDEX
    assert_stderr_contains ".agents/skills/delta/: no row for \`delta\`"
}

case_index_row_without_directory() {
    local root
    root=$(make_fixture)
    mv "${root}/.agents/skills/beta" "${CASE_DIR}/beta"
    capture "${BASH}" "${CHECKS}/skills-index-complete.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_INDEX
    assert_stderr_contains "AGENTS.md:$(grep -n "^| ${BT}beta${BT}" "${root}/AGENTS.md" | cut -d: -f1): \`beta\` has a Skills table row but no .agents/skills/beta/ directory"
    assert_stderr_not_contains "\`alpha\`" "an indexed skill with a directory reported"
}

case_index_no_skills_table() {
    local root
    root=$(make_fixture)
    sed 's/^## Skills$/## Capabilities/' "${root}/AGENTS.md" >"${CASE_DIR}/x"
    mv "${CASE_DIR}/x" "${root}/AGENTS.md"
    capture "${BASH}" "${CHECKS}/skills-index-complete.sh" --root "${root}"
    assert_exit 1
    assert_contract ERR_CHECK_SKILL_INDEX
    assert_stderr_contains "no table under a \`## Skills\` heading"
}

run_case "run-all: passes on a conforming tree" case_run_all_passes
run_case "run-all: two broken checks are both reported" case_run_all_reports_every_failure
run_case "run-all: rejects an unknown argument" case_run_all_rejects_unknown_argument
run_case "lib: rejects a --root that does not exist" case_check_rejects_missing_root
run_case "recipes: passes on a conforming tree" case_recipes_pass
run_case "recipes: a bogus inline recipe fails" case_recipes_bogus_inline
run_case "recipes: a bogus second recipe in a chain fails" case_recipes_bogus_second_in_chain
run_case "recipes: a bogus recipe in a fenced block fails" case_recipes_bogus_in_fenced_block
run_case "recipes: just missing from PATH fails" case_recipes_just_missing
run_case "workflows: passes on a conforming tree" case_workflows_pass
run_case "workflows: passes with no .github/actions/" case_workflows_pass_without_actions_dir
run_case "workflows: no top-level permissions fails" case_workflows_missing_permissions
run_case "workflows: a tag pin in a workflow fails" case_workflows_tag_pin_in_workflow
run_case "workflows: a tag pin in a composite action fails" case_workflows_tag_pin_in_composite_action
run_case "workflows: a SHA without a version comment fails" case_workflows_sha_without_version_comment
run_case "workflows: a short SHA fails" case_workflows_short_sha
run_case "frontmatter: passes on a conforming tree" case_frontmatter_pass
run_case "frontmatter: a third key fails" case_frontmatter_third_key
run_case "frontmatter: a name differing from the directory fails" case_frontmatter_name_mismatch
run_case "frontmatter: an empty description fails" case_frontmatter_empty_description
run_case "frontmatter: no frontmatter block fails" case_frontmatter_missing_block
run_case "frontmatter: an unclosed block fails" case_frontmatter_unclosed_block
run_case "frontmatter: a skill directory without SKILL.md fails" case_frontmatter_missing_skill_file
run_case "index: passes, and ignores the ### Rules table" case_index_pass_ignores_rules_table
run_case "index: a skill directory without a row fails" case_index_directory_without_row
run_case "index: a row without a directory fails" case_index_row_without_directory
run_case "index: no Skills table fails" case_index_no_skills_table
finish
