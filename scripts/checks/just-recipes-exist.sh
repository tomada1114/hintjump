#!/usr/bin/env bash
# Every `just <recipe>` that AGENTS.md names must be a recipe the justfile defines,
# so a renamed or removed recipe cannot leave the agent guide pointing at nothing.
#
#   scripts/checks/just-recipes-exist.sh [--root DIR]
#
# Tokens, read from <root>/AGENTS.md:
#   - inside an inline code span (text between single backticks), every
#     `just <name>` — so `just generate && just build` yields both recipes and
#     `just lint`, then `just test-scripts` yields each one;
#   - inside a fenced code block, the same, on every line (the Quick Reference);
#   - <name> starts with a letter or `_` and continues with letters, digits, `_`,
#     or `-` (just's own recipe-name rule), so `just --list` or a placeholder like
#     `just <recipe>` names no recipe, and `just` must not be the tail of a longer
#     word (`adjust x` is not a token). Prose outside backticks is never read.
# The recipes are the names `just --summary --justfile <root>/justfile` prints
# (public recipes; `[private]` and `_`-prefixed ones are not listed). Only
# AGENTS.md is read — CONTRIBUTING.md and README.md are not covered.
#
# Requires `just` on PATH (a mise tool: `mise exec -- …` locally, jdx/mise-action
# in CI). Git work tree: not required — the check reads files under --root, which
# defaults to the checkout containing this script (scripts/checks/lib.sh).
#
# Errors (each followed by Expected:/Actual:/Next: lines, exit 1):
#   ERR_CHECK_USAGE           unknown argument, or a --root DIR that does not exist
#   ERR_CHECK_INPUT_MISSING   <root>/AGENTS.md or <root>/justfile does not exist
#   ERR_CHECK_TOOL_MISSING    `just` is not on PATH
#   ERR_CHECK_JUST_FAILED     `just --summary` could not read the justfile
#   ERR_CHECK_RECIPE_MISSING  AGENTS.md names a recipe the justfile does not define
set -euo pipefail

# shellcheck source=scripts/checks/lib.sh
. "$(dirname "$0")/lib.sh"
check_parse_args "scripts/checks/just-recipes-exist.sh" "$@"
check_require_file "AGENTS.md"
check_require_file "justfile"

if ! command -v just >/dev/null 2>&1; then
    check_fail ERR_CHECK_TOOL_MISSING "'just' is not on PATH" \
        "just (pinned in mise.toml) on PATH" "\`command -v just\` found nothing" \
        "run it through mise — \`mise exec -- scripts/checks/just-recipes-exist.sh\` or \`just check-harness\`"
fi

if ! SUMMARY=$(just --summary --justfile "${CHECK_ROOT}/justfile" 2>&1); then
    check_fail ERR_CHECK_JUST_FAILED "\`just --summary\` could not read ${CHECK_ROOT}/justfile" \
        "\`just --summary --justfile ${CHECK_ROOT}/justfile\` to list the recipes" \
        "$(printf '%s\n' "${SUMMARY}" | head -n 1)" \
        "run \`just --summary --justfile ${CHECK_ROOT}/justfile\` and fix the justfile"
fi
RECIPES=" $(printf '%s' "${SUMMARY}" | tr '\n\t' '  ') "

# Prints one `<line>\t<recipe>` per token, in file order.
TOKENS=$(awk '
    function scan(text,    s, tok) {
        s = " " text
        while (match(s, /[^A-Za-z0-9_-]just[ \t]+[A-Za-z_][A-Za-z0-9_-]*/)) {
            tok = substr(s, RSTART + 1, RLENGTH - 1)
            sub(/^just[ \t]+/, "", tok)
            print NR "\t" tok
            s = substr(s, RSTART + RLENGTH)
        }
    }
    /^[ \t]*```/ { fenced = !fenced; next }
    fenced { scan($0); next }
    {
        n = split($0, parts, "`")
        for (i = 2; i <= n; i += 2) scan(parts[i])
    }
' "${CHECK_ROOT}/AGENTS.md")

while IFS="$(printf '\t')" read -r line recipe; do
    [ -n "${recipe}" ] || continue
    case "${RECIPES}" in
        *" ${recipe} "*) ;;
        *) check_problem "AGENTS.md:${line}: \`just ${recipe}\` — no recipe named '${recipe}'" ;;
    esac
done <<EOF
${TOKENS}
EOF

check_report ERR_CHECK_RECIPE_MISSING "AGENTS.md names a just recipe the justfile does not define" \
    "every \`just <recipe>\` in AGENTS.md to be listed by \`just --summary\`" \
    "rename the reference in AGENTS.md to an existing recipe, or add the recipe to the justfile"
check_finish "just-recipes-exist: every just recipe AGENTS.md names exists."
