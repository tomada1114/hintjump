#!/usr/bin/env bash
# Tests for scripts/test-local.sh: that it runs the local-machine tests with the
# opt-in set, passes swift test's exit status through, and fails a run that ended
# without Swift Testing's summary line even when swift test exited 0.
#
# `swift` is stubbed in every case, so nothing is built and no local-machine test
# runs. The script cds into Packages/HintjumpKit but, with swift stubbed, writes
# nothing there.
set -euo pipefail

# shellcheck source=scripts/tests/lib.sh
. "$(dirname "$0")/lib.sh"
trap cleanup_temp EXIT

TEST_LOCAL_SH="${REPO_ROOT}/scripts/test-local.sh"
SUMMARY='✔ Test run with 29 tests in 10 suites passed after 1.2 seconds.'
FAILED_SUMMARY='✘ Test run with 29 tests in 10 suites failed after 1.2 seconds with 1 issue.'

# stub_swift OUTPUT STATUS — swift prints OUTPUT, records the opt-in it was given,
# and exits STATUS.
stub_swift() {
    export STUB_OUTPUT="$1" STUB_STATUS="$2" STUB_ENV="${STUB_BIN}/swift.env"
    # shellcheck disable=SC2016 # expanded by the stub at run time, not here
    stub_command swift 'echo "RUN_LOCAL_MACHINE_TESTS=${RUN_LOCAL_MACHINE_TESTS-unset}" >>"${STUB_ENV}"; printf "%s\n" "${STUB_OUTPUT}"; exit "${STUB_STATUS}"'
}

case_runs_the_platform_tests_opted_in() {
    stub_swift "${SUMMARY}" 0
    capture "${TEST_LOCAL_SH}"
    assert_exit 0
    assert_stdout_contains "${SUMMARY}"
    [ "$(cat "${STUB_BIN}/swift.log")" = "test --filter HintjumpPlatformTests" ] ||
        _fail "swift was called with: $(cat "${STUB_BIN}/swift.log")"
    [ "$(cat "${STUB_ENV}")" = "RUN_LOCAL_MACHINE_TESTS=1" ] ||
        _fail "swift ran with $(cat "${STUB_ENV}")"
}

case_passes_a_test_failure_through() {
    stub_swift "${FAILED_SUMMARY}" 1
    capture "${TEST_LOCAL_SH}"
    assert_exit 1
    assert_stdout_contains "${FAILED_SUMMARY}"
    assert_stderr_not_contains "ERR_TESTLOCAL_NO_SUMMARY"
}

case_a_single_test_summary_counts() {
    stub_swift '✔ Test run with 1 test in 1 suite passed after 0.1 seconds.' 0
    capture "${TEST_LOCAL_SH}"
    assert_exit 0
}

assert_no_summary_failure() {
    assert_exit 1
    head -n 1 "${CASE_DIR}/stderr" | grep -q '^ERR_TESTLOCAL_NO_SUMMARY: ' ||
        _fail "first stderr line is not ERR_TESTLOCAL_NO_SUMMARY"
    assert_stderr_contains "Expected: "
    assert_stderr_contains "Actual: "
    assert_stderr_contains "Next: "
}

case_fails_a_silent_exit_zero() {
    stub_swift '◇ Test a click arrives started.' 0
    capture "${TEST_LOCAL_SH}"
    assert_no_summary_failure
    assert_stderr_contains "swift test exited 0"
}

case_fails_a_crash_without_a_summary() {
    stub_swift 'error: Exited with unexpected signal code 11' 1
    capture "${TEST_LOCAL_SH}"
    assert_no_summary_failure
    assert_stderr_contains "swift test exited 1"
}

run_case "runs HintjumpPlatformTests with RUN_LOCAL_MACHINE_TESTS=1" case_runs_the_platform_tests_opted_in
run_case "a failing run keeps swift test's exit status" case_passes_a_test_failure_through
run_case "a one-test summary line counts as a summary" case_a_single_test_summary_counts
run_case "a run ending without its summary fails even on exit 0" case_fails_a_silent_exit_zero
run_case "a run ending without its summary on a non-zero exit names it" case_fails_a_crash_without_a_summary
finish
