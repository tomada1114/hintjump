#!/usr/bin/env bash
# Run the MyAppKit test suite with code coverage and enforce a line-coverage
# floor on Sources/MyAppCore. The report below is filtered to that path, so MyAppUI
# and MyAppPlatform are outside it rather than measured and waived. The floor is
# honest because all logic lives in Core: views render it and MyAppPlatform adapters
# only translate for it, so neither holds a decision a test could catch
# (AGENTS.md > Architecture). MyAppPlatformTests does link MyAppPlatform, but its
# tests are skipped unless RUN_LOCAL_MACHINE_TESTS=1 (`just test-local`) — so they
# contribute nothing here, and measuring Platform would gate the build on whether a
# human opted in.
#
# Swift's llvm-cov has no dependable branch metric, so this gates on LINE
# coverage (uv-template gates on branch coverage; documented divergence).
#
# The floor is COVERAGE_FLOOR below and nothing else: no environment variable or
# flag moves it, so every change to it is a reviewed diff of this file. It is
# raised, never lowered (AGENTS.md, "Important Reminders").
#
#   scripts/coverage.sh    (what `just test` and CI's test and release jobs run)
#
# Git work tree: not required — it runs from the package directory next to it.
#
# Errors (each followed by Expected:/Actual:/Next: lines, exit 1):
#   ERR_COVERAGE_OVERRIDE_REMOVED  COVERAGE_MIN is set; it is no longer read, and
#                                  the script stops before running any test
# A coverage result below the floor predates this contract and exits non-zero
# with a one-line message from the embedded Python.
set -euo pipefail

readonly COVERAGE_FLOOR=80

# The old environment override is rejected rather than silently ignored, so a
# caller who still sets it learns the floor no longer moves that way.
if [ -n "${COVERAGE_MIN+set}" ]; then
    echo "ERR_COVERAGE_OVERRIDE_REMOVED: COVERAGE_MIN is no longer read." >&2
    echo "Expected: the floor comes from COVERAGE_FLOOR in scripts/coverage.sh (currently ${COVERAGE_FLOOR})." >&2
    echo "Actual: COVERAGE_MIN is set in the environment (value: '${COVERAGE_MIN}')." >&2
    echo "Next: unset COVERAGE_MIN and rerun; to raise the floor, edit COVERAGE_FLOOR in a reviewed commit — it is never lowered (AGENTS.md)." >&2
    exit 1
fi

cd "$(dirname "$0")/../Packages/MyAppKit"

swift test --enable-code-coverage
CODECOV_JSON="$(swift test --show-codecov-path)"

python3 - "$CODECOV_JSON" "$COVERAGE_FLOOR" <<'PY'
import json, sys

data = json.load(open(sys.argv[1]))
threshold = float(sys.argv[2])
covered = total = 0
for f in data["data"][0]["files"]:
    if "/Sources/MyAppCore/" not in f["filename"]:
        continue
    s = f["summary"]["lines"]
    covered += s["covered"]
    total += s["count"]
    pct = 100.0 * s["covered"] / s["count"] if s["count"] else 100.0
    print(f'{f["filename"]}: {pct:.1f}%')
if total == 0:
    sys.exit("coverage: no MyAppCore files found — gate misconfigured")
pct = 100.0 * covered / total
print(f"MyAppCore line coverage: {pct:.1f}% (floor {threshold}%)")
# Two decimals in the failure message so a near-miss never rounds up to the
# floor itself (e.g. 79.96% displayed as "80.0% is below the 80% floor").
sys.exit(0 if pct >= threshold else f"coverage {pct:.2f}% is below the {threshold}% floor")
PY
