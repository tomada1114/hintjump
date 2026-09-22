#!/usr/bin/env bash
# Run the local-machine adapter tests (HintjumpPlatformTests) and fail when the run
# ends without its summary line. What `just test-local` runs.
#
#   scripts/test-local.sh
#
# Sets RUN_LOCAL_MACHINE_TESTS=1, the opt-in the `.requiresLocalMachine` trait reads,
# and passes swift test's own exit status through. The one thing it adds is the check
# swift test does not make: a run whose process ends before Swift Testing prints its
# closing `Test run with N tests in M suites …` line can still exit 0, and a silent
# exit 0 reads as a pass. So the output is streamed as usual, kept, and searched for
# that line afterwards.
#
# `swift` is taken from PATH, which the caller provides (`mise exec --` in the recipe).
#
# Git work tree: not required — it runs from the package directory next to it.
#
# Errors (each followed by Expected:/Actual:/Next: lines, exit 1):
#   ERR_TESTLOCAL_NO_SUMMARY  swift test ended without Swift Testing's summary line
# A test failure is swift test's own non-zero exit, passed through unchanged.
set -euo pipefail

cd "$(dirname "$0")/../Packages/HintjumpKit"

LOG=$(mktemp "${TMPDIR:-/tmp}/test-local.XXXXXX")
trap 'rm -f "${LOG}"' EXIT

set +e
RUN_LOCAL_MACHINE_TESTS=1 swift test --filter 'HintjumpPlatformTests' 2>&1 | tee "${LOG}"
STATUS=${PIPESTATUS[0]}
set -e

if ! grep -Eq 'Test run with [0-9]+ tests? in [0-9]+ suites? (passed|failed)' "${LOG}"; then
    echo "ERR_TESTLOCAL_NO_SUMMARY: the test run ended without Swift Testing's summary line." >&2
    echo "Expected: a closing \`Test run with N tests in M suites passed|failed …\` line." >&2
    echo "Actual: no such line in the output; swift test exited ${STATUS}, and any test shown as started above without a result never finished." >&2
    echo "Next: rerun \`just test-local\`; if it ends early again, the last suite started above is the one ending the process — do not paste this run into a PR as evidence." >&2
    exit 1
fi
exit "${STATUS}"
