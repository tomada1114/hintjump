#!/usr/bin/env bash
# Template bootstrap: rename every placeholder to your app's identity.
#
#   scripts/bootstrap.sh NewName [--bundle-id-prefix ID] [--github-user USER]
#                                [--author "Full Name"] [--email ADDRESS] [--repo slug]
#
# Replaces (in all git-tracked text files):
#   MyApp        -> NewName            (also MyAppKit/MyAppCore/MyAppUI/MyAppApp)
#   my-app       -> repo slug          (default: kebab-case of NewName)
#   com.example  -> --bundle-id-prefix (kept if omitted)
#   your-username / Your Name / you@example.com -> optional args (kept if omitted)
#
# Then renames MyApp* paths and regenerates the Xcode project.
# Running it again with the same name is a no-op, so it is safe to re-run
# (values a previous run already replaced are not replaced again).
set -euo pipefail

# The placeholder literals are quote-split so replace() below never rewrites
# this script's own match sources — a re-run keeps matching the original
# placeholders instead of whatever a previous run substituted for them.
PH_NAME='My''App'
PH_SLUG='my''-app'
PH_BUNDLE='com''.example'
PH_USER='your''-username'
PH_AUTHOR='Your'' Name'
PH_EMAIL='you''@example.com'

usage() {
    # Print the header comment: lines after the shebang up to the first non-comment.
    awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"
    exit 1
}

[ $# -ge 1 ] || usage
NEW_NAME="$1"
shift

if ! [[ "${NEW_NAME}" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
    echo "error: '${NEW_NAME}' is not PascalCase (expected ^[A-Z][A-Za-z0-9]*$)" >&2
    exit 1
fi
if [[ "${NEW_NAME}" == *"${PH_NAME}"* ]]; then
    echo "error: '${NEW_NAME}' contains the placeholder '${PH_NAME}' — a re-run would corrupt the rename; pick a different name" >&2
    exit 1
fi

# Default slug: kebab-case of NewName (DemoApp -> demo-app, HTTPServer -> http-server).
DEFAULT_SLUG=$(echo "${NEW_NAME}" | perl -pe 's/([A-Z]+)([A-Z][a-z])/$1-$2/g; s/([a-z0-9])([A-Z])/$1-$2/g' | tr '[:upper:]' '[:lower:]')

BUNDLE_ID_PREFIX=""
GITHUB_USER=""
AUTHOR=""
EMAIL=""
REPO_SLUG="${DEFAULT_SLUG}"

while [ $# -gt 0 ]; do
    case "$1" in
        --bundle-id-prefix) BUNDLE_ID_PREFIX="$2"; shift 2 ;;
        --github-user)      GITHUB_USER="$2";      shift 2 ;;
        --author)           AUTHOR="$2";           shift 2 ;;
        --email)            EMAIL="$2";            shift 2 ;;
        --repo)             REPO_SLUG="$2";        shift 2 ;;
        *) echo "error: unknown option '$1'" >&2; usage ;;
    esac
done

if [[ "${REPO_SLUG}" == *"${PH_SLUG}"* ]]; then
    echo "error: repo slug '${REPO_SLUG}' contains the placeholder '${PH_SLUG}' — pass a different --repo" >&2
    exit 1
fi

cd "$(dirname "$0")/.."

# replace() enumerates git-tracked files, so a checkout without .git cannot be
# bootstrapped (e.g. a GitHub ZIP download, or a clone whose .git was removed).
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: bootstrap.sh needs a git checkout to enumerate files (git ls-files)." >&2
    echo "       If you removed .git, re-create it first: git init && git add -A" >&2
    exit 1
fi

replace() { # replace <from> <to> — literal replacement in all tracked text files
    local from="$1" to="$2" file
    [ "${from}" = "${to}" ] && return 0
    git ls-files -z | while IFS= read -r -d '' file; do
        [ -f "${file}" ] || continue
        grep -Iq . "${file}" 2>/dev/null || continue # skip binary and empty files
        grep -qF -- "${from}" "${file}" || continue  # leave non-matching files untouched
        FROM="${from}" TO="${to}" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "${file}"
    done
}

# Reset the template's own CHANGELOG history for the new project. Guarded by a
# marker so a re-run (documented as safe) never wipes the new app's entries.
if grep -qF 'Initial template: XcodeGen-generated app shell' CHANGELOG.md 2>/dev/null; then
    echo "==> Resetting CHANGELOG.md for the new project"
    cat > CHANGELOG.md <<EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)

[Unreleased]: https://github.com/${PH_USER}/${PH_SLUG}/commits/main
EOF
fi

echo "==> Replacing placeholders"
replace "${PH_NAME}" "${NEW_NAME}"
replace "${PH_SLUG}" "${REPO_SLUG}"
[ -n "${BUNDLE_ID_PREFIX}" ] && replace "${PH_BUNDLE}" "${BUNDLE_ID_PREFIX}"
[ -n "${GITHUB_USER}" ] && replace "${PH_USER}" "${GITHUB_USER}"
[ -n "${AUTHOR}" ] && replace "${PH_AUTHOR}" "${AUTHOR}"
[ -n "${EMAIL}" ] && replace "${PH_EMAIL}" "${EMAIL}"

echo "==> Renaming ${PH_NAME}* paths"
# Drop any stale generated project first; it is rebuilt below.
rm -rf "${PH_NAME}.xcodeproj" "${NEW_NAME}.xcodeproj"
# -depth renames the deepest entries first, so only basenames need rewriting.
# Skip VCS internals and build artifacts (SwiftPM's Packages/*/.build and the
# derived-data dir build/) — they are regenerable and full of matching paths.
find . -depth -name "*${PH_NAME}*" \
    -not -path "./.git/*" -not -path "*/.build/*" -not -path "./build/*" \
    | while IFS= read -r path; do
    base=$(basename "${path}")
    # Unquoted expansions: bash 3.2 (the runners' /bin/bash) treats quotes
    # inside ${var//pat/rep} literally. Both values are validated alphanumeric.
    target="$(dirname "${path}")/${base//${PH_NAME}/${NEW_NAME}}"
    if [ "${path}" != "${target}" ]; then
        mv "${path}" "${target}"
    fi
done

echo "==> Regenerating Xcode project"
if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
elif command -v mise >/dev/null 2>&1; then
    mise exec -- xcodegen generate
else
    echo "warning: xcodegen not found — run 'just generate' after installing tools" >&2
fi

echo
echo "Bootstrap complete: ${PH_NAME} -> ${NEW_NAME} (repo slug: ${REPO_SLUG})"
[ -n "${BUNDLE_ID_PREFIX}" ] && echo "  bundle-id prefix: ${BUNDLE_ID_PREFIX}"
echo
echo "Next steps:"
echo "  1. Verify the rename: just install && just check"
echo "  2. Create the label set on the new repository: just labels"
echo "  3. Review the changes: git diff"
echo "  4. Review LICENSE's copyright line (year and holder)"
echo "  5. Check for leftovers: rg -i '${PH_NAME}|${PH_SLUG}|${PH_BUNDLE}|${PH_USER}'"
echo "  6. Commit: git add -A && git commit -m 'chore: bootstrap ${NEW_NAME} from template'"
echo "  7. Optional, repository admin only, after pushing that commit: just ruleset"
echo "     (applies the main branch ruleset, which then requires pull requests)"
