#!/usr/bin/env bash
# Tests for scripts/guard/credentials.sh, a sourced library (not a script directly
# under scripts/), so it gets its own test file named after it.
#
# Fixture safety: every credential-shaped value is assembled at runtime from pieces
# that do not match on their own (the prefix is split across two quoted strings), so
# this file passes the very guard it tests and GitHub push protection. Never write a
# whole value as one literal here.
set -euo pipefail
# shellcheck source=scripts/tests/lib.sh
. "$(dirname "$0")/lib.sh"
trap cleanup_temp EXIT
# shellcheck source=scripts/guard/credentials.sh
. "${REPO_ROOT}/scripts/guard/credentials.sh"

BODY_40="0123456789abcdefghijABCDEFGHIJ0123456789"
GH_CLASSIC="gh""p_${BODY_40}"
GH_OAUTH="gh""o_${BODY_40}"
GH_FINE_GRAINED="github""_pat_11ABCDEFG0123456789_abcdefghij"
AWS_KEY_ID="AK""IA""ABCDEFGHIJ012345"
AWS_SESSION_KEY_ID="AS""IA""ABCDEFGHIJ012345"
PEM_RSA="-----BEGIN ""RSA PRIVATE KEY-----"
PEM_PKCS8="-----BEGIN ""PRIVATE KEY-----"
PEM_OPENSSH="-----BEGIN ""OPENSSH PRIVATE KEY-----"

# write_file NAME CONTENT — writes CONTENT into a fresh file under CASE_DIR and prints
# its path.
write_file() {
    printf '%s\n' "$2" >"${CASE_DIR}/$1"
    echo "${CASE_DIR}/$1"
}

# expect_category CATEGORY VALUE — VALUE embedded in ordinary text is detected as
# CATEGORY, and the output is exactly the category name, never the value.
expect_category() {
    local file
    file=$(write_file sample.txt "let config = \"$2\" // pasted by mistake")
    capture credential_category "${file}"
    assert_exit 0
    [ "$(cat "${CASE_DIR}/stdout")" = "$1" ] || _fail "expected stdout to be exactly $1"
    assert_stdout_not_contains "$2" "the credential-shaped value"
    assert_stderr_not_contains "$2" "the credential-shaped value"
}

expect_nothing() {
    capture credential_category "$1"
    assert_exit 1
    [ ! -s "${CASE_DIR}/stdout" ] || _fail "expected no output for a clean file"
}

case_private_key_detected() {
    expect_category private-key "${PEM_RSA}"
    expect_category private-key "${PEM_PKCS8}"
    expect_category private-key "${PEM_OPENSSH}"
}

case_github_tokens_detected() {
    expect_category github-token "${GH_CLASSIC}"
    expect_category github-token "${GH_OAUTH}"
    expect_category github-token "${GH_FINE_GRAINED}"
}

case_aws_key_ids_detected() {
    expect_category aws-access-key-id "${AWS_KEY_ID}"
    expect_category aws-access-key-id "${AWS_SESSION_KEY_ID}"
}

# A binary file (NUL bytes around the value) is scanned too, thanks to grep -a.
case_binary_file_scanned() {
    local file="${CASE_DIR}/blob.bin"
    { printf '\000\001\002'; printf '%s' "${GH_CLASSIC}"; printf '\000\377'; } >"${file}"
    capture credential_category "${file}"
    assert_exit 0
    assert_stdout_contains "github-token"
    assert_stdout_not_contains "${GH_CLASSIC}" "the credential-shaped value"
}

case_swift_source_clean() {
    expect_nothing "${REPO_ROOT}/Packages/MyAppKit/Sources/MyAppCore/CounterViewModel.swift"
    expect_nothing "$(write_file View.swift 'struct KeyView { let apiKeyName = "GITHUB_TOKEN"; let pem = "-----BEGIN CERTIFICATE-----" }')"
}

case_markdown_clean() {
    expect_nothing "${REPO_ROOT}/README.md"
    local short_prefix="gh""p_abc"
    expect_nothing "$(write_file notes.md "$(printf '%s\n' "# Keys" \
        "Store the token in the keychain; never paste a private key here." \
        "A short prefix like ${short_prefix} is not a token.")")"
}

# The library's own source must pass itself, or it could never be committed.
case_guard_sources_clean() {
    expect_nothing "${REPO_ROOT}/scripts/guard/credentials.sh"
    expect_nothing "${REPO_ROOT}/scripts/guard/paths.sh"
    expect_nothing "${REPO_ROOT}/scripts/check-staged.sh"
    expect_nothing "$0"
}

case_too_short_values_not_detected() {
    expect_nothing "$(write_file short.txt "gh""p_${BODY_40:0:35} ${AWS_KEY_ID:0:19}")"
}

case_unreadable_file_returns_2() {
    capture credential_category "${CASE_DIR}/does-not-exist"
    assert_exit 2
}

run_case "PEM private-key headers are detected as private-key" case_private_key_detected
run_case "classic, OAuth, and fine-grained GitHub tokens are detected" case_github_tokens_detected
run_case "AKIA and ASIA access key ids are detected" case_aws_key_ids_detected
run_case "a binary file is scanned and the value is not printed" case_binary_file_scanned
run_case "ordinary Swift content yields nothing" case_swift_source_clean
run_case "ordinary Markdown content yields nothing" case_markdown_clean
run_case "the guard's own sources and this test yield nothing" case_guard_sources_clean
run_case "values shorter than a pattern's bound are not detected" case_too_short_values_not_detected
run_case "a missing file returns 2" case_unreadable_file_returns_2
finish
