---
name: starting-an-app
description: >
  Covers turning this template into a new application with scripts/bootstrap.sh: its
  arguments, the placeholder literals it replaces across git-tracked files, re-running
  it safely, the leftover check, and what the new repository keeps untouched. Use when
  starting an app from this repository, running or editing scripts/bootstrap.sh, a
  rename left a placeholder behind, CI's bootstrap-smoke job fails, or setting up a new
  repository's labels (just labels) and branch ruleset (just ruleset).
---

# Starting an App

**Owns:** turning this repository into a new application — the rename
`scripts/bootstrap.sh` performs, the order around it, and what the new app keeps.
**Does not own:** how a skill is authored or mirrored (`authoring-skills`); how a
repository script is written or tested (`writing-repo-scripts`); what a gate file may
contain (`changing-gates`); the README's own prose (`updating-docs`).

This repository ships a bootstrap script on purpose. Its placeholders are a fixed,
small set of literals — `MyApp`, `my-app`, `com.example`, `your-username`, `Your Name`,
and `you@example.com` — with no framework inventory to enumerate, so a single literal
find-and-replace over tracked files is the whole job, and a script does it more
reliably than a checklist would. The script stays in the tree after it runs, so the
record of what it did is a file anyone can still read, and CI's `bootstrap-smoke` job
runs it on a pristine clone on every push, so it cannot silently rot.

## The order

Rename first, so nothing downstream is written against the template's identity. Then
verify, then hand-edit what a literal replace cannot decide, then set up the new
repository on GitHub. `README.md`'s "Using This Template" section is the reader-facing
list of those steps; the script prints the same list when it finishes.

## The rename

```bash
scripts/bootstrap.sh CoolApp --bundle-id-prefix io.example --github-user janedoe \
  --author "Jane Doe" --email jane@example.com [--repo cool-app]
```

- **Arguments** (the script's `usage()` prints its header comment). The name is
  required and must be PascalCase. The slug defaults to the kebab-case of the name
  (`--repo` overrides it); the other four options are optional, and an omitted one
  leaves its placeholder in place. A name or slug that itself contains the
  placeholder is refused, because a later run would match it again and corrupt it.
- **The placeholder map** is the six `PH_*` variables at the top of the script. Each
  literal is quote-split there (`'My''App'`) so the replacement never rewrites the
  script's own match sources — a re-run keeps looking for the original placeholders.
- **`replace()`** walks `git ls-files`, so only tracked files are touched: stage a new
  file before running if it should be renamed too. It skips binary and empty files and
  leaves a file without a match untouched. This is why the script refuses to run
  outside a git checkout (see `writing-repo-scripts`).
- **Paths** named after the app (`MyAppKit`, `MyAppCore`, …) are renamed deepest-first,
  skipping `.git/` and build output, and the Xcode project is regenerated.
- **`CHANGELOG.md`** is reset to a one-entry history for the new project, guarded by a
  marker line so a re-run never wipes the new app's own entries.
- **Idempotent:** running it again with the same name is a no-op.

When it finishes, it prints next steps, including a leftover check: an `rg -i` over the
app name, slug, bundle-id, and GitHub-user placeholders. Anything it still finds is
either an optional argument you omitted or a string written in a shape the literal
replace cannot see — fix those by hand. `README.md`'s own leftover command spells the placeholders with `.` wildcards
for the same reason the script quote-splits them.

Changing the script means keeping `bootstrap-smoke` green: it bootstraps a clone as
`DemoApp`, asserts no placeholder survives, asserts the `CHANGELOG.md` reset, then runs
`swift test` and an `xcodebuild` on the renamed tree. Its leftover grep is
case-insensitive and allows a missing hyphen, so a new mention of the app name in a
spelling the literal replace does not cover (all lowercase, say) fails that job.

## What the new app keeps

Everything below is about the repository rather than the application, so it survives
the rename unchanged and is most of what starting from this template buys:

- **The gate set** — the `justfile` recipes and the scripts under `scripts/` they call,
  and `.github/workflows/`. A red run early in a new project is an argument for fixing
  the code, never for deleting the check that found it. The one job that is about the
  template rather than the app is `bootstrap-smoke`: once the rename has run there are
  no placeholders left for it to rename, so it renames nothing and then fails to find
  the `DemoApp` package it expects. Retire it deliberately — the workflow job and its
  `Template Bootstrap Smoke` entry in `.github/rulesets/main.json` together.
- **The commit-time guard** — `.githooks/pre-commit` and its "Staged guard" section
  (`scripts/check-staged.sh`, with the rules in `scripts/guard/`), the one layer that
  stops a secret-shaped path or credential before it reaches history. It knows nothing
  about the app, so keep it whatever the app becomes.
- **The skills** under `.agents/skills/` and their mirror in `.claude/skills/`. Drop one
  only when the subject it owns actually leaves the repository — this one, for example,
  once the rename has landed. **REQUIRED:** `authoring-skills` for the mirror loop and
  the `AGENTS.md` Skills table row that `just check-harness` requires for every skill.
- **The label taxonomy** — `.github/labels.yml`, created on the new repository by
  `just labels`. Run it early: GitHub silently drops a label that an issue form applies
  when the repository does not have it yet. **BACKGROUND:** `triaging-issues` for what
  the labels mean.
- **The branch ruleset** — `.github/rulesets/main.json`, applied by a repository admin
  with `just ruleset`. "Use this template" does not copy rulesets, so the new
  repository has no protection on `main` until someone runs it; on a private
  repository it needs a paid GitHub plan. Run it last, after the bootstrap commit is on
  `main`: from then on every change needs a pull request whose required checks pass,
  so the check list must name only jobs the new app still runs.

Both `just labels` and `just ruleset` write to the live repository, so they need a
human's sign-off (`AGENTS.md`'s "Security and human approval") — for a brand-new
repository, that is its owner deciding to run them.
