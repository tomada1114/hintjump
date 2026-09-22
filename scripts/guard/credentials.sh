# shellcheck shell=bash
# Content-shaped commit rules: text that must never land in a tracked file.
# Sourced, never executed (like scripts/tests/lib.sh, it carries no shebang or `set`
# line of its own):
#
#   . "scripts/guard/credentials.sh"
#   if category=$(credential_category some-file); then echo "found: ${category}"; fi
#
# Read by scripts/check-staged.sh, which runs it on the staged blob of every path
# that scripts/guard/paths.sh let through.
#
# Literal patterns only, no entropy heuristic: start narrow and add a pattern only
# when a real false negative shows up, with a case in
# scripts/tests/guard-credentials_test.sh. Each pattern is written so that its own
# source text does not match it, which is what lets this file be committed through
# the very guard that reads it; tests assemble their secret-shaped fixtures at
# runtime for the same reason.
#
# grep runs with -a so a binary file is scanned too, and under LC_ALL=C so a byte
# sequence that is not valid in the caller's locale cannot make it error or skip.
# -E with a `{n,}` bound and -a behave the same in BSD grep (macOS) and GNU grep.

# CREDENTIAL_PATTERNS — one "category<TAB>extended regex" per line, checked in order.
CREDENTIAL_PATTERNS='private-key	-----BEGIN ([A-Z]+ )*PRIVATE KEY-----
github-token	gh[pousr]_[A-Za-z0-9]{36,}
github-token	github_pat_[A-Za-z0-9_]{22,}
aws-access-key-id	(AKIA|ASIA)[A-Z0-9]{16}'

# credential_category FILE — prints the first matching category name (never the
# matched text) and returns 0 when FILE holds credential-shaped content; returns 1
# when it holds none, and 2 (printing nothing) when FILE cannot be read.
credential_category() {
    local file="$1" category pattern status
    [ -f "${file}" ] && [ -r "${file}" ] || return 2
    while IFS="$(printf '\t')" read -r category pattern; do
        [ -n "${category}" ] || continue
        status=0
        # Through env, not a bare LC_ALL=C prefix: Homebrew bash re-inits its locale
        # for a prefixed command in the forked child, which can SIGSEGV on macOS.
        env LC_ALL=C grep -a -E -q -e "${pattern}" -- "${file}" || status=$?
        case "${status}" in
            0)
                echo "${category}"
                return 0
                ;;
            1) ;;
            *) return 2 ;;
        esac
    done <<EOF
${CREDENTIAL_PATTERNS}
EOF
    return 1
}
