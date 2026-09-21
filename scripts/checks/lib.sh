# shellcheck shell=bash
# Shared helpers for the harness-conformance checks in scripts/checks/. Sourced,
# never executed, so it carries no shebang or `set` line of its own:
#
#   . "$(dirname "$0")/lib.sh"
#   check_parse_args "scripts/checks/x.sh" "$@"     # sets CHECK_ROOT
#   check_require_file "AGENTS.md"
#   check_problem "AGENTS.md:12: ..."               # collect, do not stop
#   check_report ERR_CHECK_X "what failed" "expected" "next"
#   check_finish "x: ok"
#
# Every check reads files under CHECK_ROOT and nothing else. CHECK_ROOT is the
# --root DIR argument when given (tests point it at a fixture tree), otherwise the
# checkout that contains scripts/checks/ — resolved from this file's own location,
# so no git call is needed and the checks also run in a tarball of the template.
#
# Errors raised here (each followed by Expected:/Actual:/Next: lines):
#   ERR_CHECK_USAGE          unknown argument, or a --root DIR that does not exist (exit 1 now)
#   ERR_CHECK_INPUT_MISSING  a file or directory the check reads is absent (exit 1 now)
# A check's own codes are reported through check_report, which lets the check keep
# going; check_finish then exits 1 if anything was reported.

CHECKS_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK_ROOT=""
CHECK_FAILED=0
CHECK_PROBLEMS=""

# check_fail CODE WHAT EXPECTED ACTUAL NEXT — prints one failure block and exits 1.
check_fail() {
    _check_print "$@"
    exit 1
}

# _check_print CODE WHAT EXPECTED ACTUAL NEXT — ACTUAL may span several lines; the
# lines after the first are indented so the block stays readable.
_check_print() {
    echo "$1: $2" >&2
    echo "Expected: $3" >&2
    printf 'Actual: %s\n' "$4" | sed '2,$s/^/  /' >&2
    echo "Next: $5" >&2
}

# check_parse_args USAGE_NAME ARGS... — accepts only `--root DIR`.
check_parse_args() {
    local name="$1" usage
    shift
    usage="usage: ${name} [--root DIR]"
    while [ $# -gt 0 ]; do
        case "$1" in
            --root)
                [ $# -ge 2 ] || check_fail ERR_CHECK_USAGE "--root needs a directory" \
                    "--root followed by an existing directory" "no value after --root" "${usage}"
                [ -d "$2" ] || check_fail ERR_CHECK_USAGE "--root directory '$2' does not exist" \
                    "--root followed by an existing directory" "no directory at '$2'" "${usage}"
                CHECK_ROOT=$(cd "$2" && pwd)
                shift
                ;;
            *)
                check_fail ERR_CHECK_USAGE "unknown argument '$1'" \
                    "no arguments, or --root DIR" "argument '$1'" "${usage}"
                ;;
        esac
        shift
    done
    if [ -z "${CHECK_ROOT}" ]; then
        CHECK_ROOT=$(cd "${CHECKS_LIB_DIR}/../.." && pwd)
    fi
}

# check_require_file REL — fails now if CHECK_ROOT/REL does not exist.
check_require_file() {
    [ -e "${CHECK_ROOT}/$1" ] || check_fail ERR_CHECK_INPUT_MISSING "$1 does not exist under ${CHECK_ROOT}" \
        "${CHECK_ROOT}/$1 to exist" "no file or directory at ${CHECK_ROOT}/$1" \
        "run the check from a checkout of this repository, or pass --root DIR"
}

# check_problem TEXT — records one problem for the next check_report.
check_problem() {
    if [ -z "${CHECK_PROBLEMS}" ]; then
        CHECK_PROBLEMS="$1"
    else
        CHECK_PROBLEMS="${CHECK_PROBLEMS}
$1"
    fi
}

# check_report CODE WHAT EXPECTED NEXT — if any problem was recorded since the last
# report, prints one failure block listing all of them (as the Actual: lines),
# marks the check failed, and clears the list. Does not exit.
check_report() {
    [ -n "${CHECK_PROBLEMS}" ] || return 0
    local count
    count=$(printf '%s\n' "${CHECK_PROBLEMS}" | wc -l | tr -d ' ')
    _check_print "$1" "$2 (${count} problem(s))" "$3" "${CHECK_PROBLEMS}" "$4"
    CHECK_FAILED=1
    CHECK_PROBLEMS=""
}

# check_finish OK_MESSAGE — exits 1 if any report was printed, else prints OK_MESSAGE.
check_finish() {
    if [ "${CHECK_FAILED}" = 1 ]; then
        exit 1
    fi
    echo "$1"
}
