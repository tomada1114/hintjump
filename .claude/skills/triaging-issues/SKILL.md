---
name: triaging-issues
description: >
  Covers this repository's issue vocabulary: the type, priority, blocked, and on-hold
  label taxonomy declared in .github/labels.yml and synced by `just labels`, what
  `blocked: design`, `blocked: dependency`, `blocked: external`, and `on hold` mean, and
  what an issue body must contain
  (a `path:line`, an observable close condition, a `Depends on #N` line). Use when filing
  a GitHub issue, triaging or re-prioritizing the backlog, picking a `priority: P0`-`P3`
  label, choosing between `bug`/`enhancement`/`documentation`/`chore`, deferring an
  issue past the first release, editing .github/labels.yml or an issue form, or running
  `just labels`.
---

# Triaging Issues

**Owns:** this repository's issue vocabulary — the label taxonomy, what a priority
means, and what an issue body must contain. **Does not own:** implementing an issue; a
change to a gate file (`changing-gates`); any workflow beyond the tracker.

Labels carry the triage decision, so it is made once and read back rather than
re-derived every time the backlog is looked at. An issue is filed with a type label and
left untiered; triage adds the priority, and a `blocked:` or `on hold` label where one
applies.

## Priority labels

| Label | When to apply it |
|---|---|
| `priority: P0` | Reserve for a real blocking chain — another open issue names it as the blocker — or active damage (red `main`, a live vulnerability). Don't tier by how urgent an issue feels; tier by whether something is actually blocked or broken. |
| `priority: P1` | Foundational work — CI, schema, shared types, config — future issues will build on, even before any open issue names it as a dependency. Once one does, the resulting blocking chain likely makes it P0 instead of P1. |
| `priority: P2` | The default tier, used absent a specific reason to move up or down. Before leaving something here, check whether it actually blocks an open issue (P0) or is groundwork later issues will need (P1) — P2 is not a place to park work you haven't evaluated. |
| `priority: P3` | Defer only when impact is genuinely low — nobody is waiting on it and no future issue depends on it. Not a stand-in for "I don't want to do this"; an issue that matters but is unappealing to implement belongs at its real tier. |
| `blocked: design` | Applies when the approach has real, unresolved alternatives a human must choose between — not simply that no one has looked at it yet. It still gets a priority tier (see below); readiness and priority are independent judgments. |
| `blocked: dependency` | Applies only alongside a `Depends on #N` line in the body (see Ordering constraints below) — the label without a named blocker can't be verified or cleared. |
| `blocked: external` | Applies when the next step is an action nobody can take from this checkout and only the repository's owner can take at all — enrolling in a developer program, buying a domain, adding a signing secret, reading notes kept outside the repository. The body names that action. It still gets a priority tier. An agent never implements it and never clears the label; the owner removes the label once the action is done, and an issue that waits on it carries `blocked: dependency` with a `Depends on #N` line like any other. |
| `on hold` | Applies when the owner has deliberately deferred an issue past the first release (`docs/decisions.md` › "The first release's target scope"). It is not a block: the issue waits on no other issue, design, or owner action, and could be implemented today — it is out of scope by choice. It is always paired with making the issue a sub-issue of the post-v1 parent, #80, which lists everything deferred and why; a hold without that link cannot be found again when the first release ships. It keeps its priority tier. Shipping runs skip it (`shipping-issues` treats it as not ready). Taking one back on is a scope decision: the label is removed on purpose, never cleared as housekeeping. |

Priority ranks impact on the rest of the backlog, not how interesting the work is. Do
not tier an issue by how appealing it is to implement.

Reach for `on hold` instead of a `blocked:` label when nothing stands in the way but
the owner's decision not to do it in the first release. A `blocked:` label clears when
something else happens — a design is chosen, a blocker merges, the owner acts outside
the repository; `on hold` clears only when the scope itself changes.

Tier and design-readiness are independent: an issue carrying `blocked: design` still
gets a tier, so it ranks correctly the moment the block clears. Never leave a
`blocked: design` issue untiered on the assumption that the tier can wait — it cannot be
re-derived later without redoing the judgment.

A label that turns out to be wrong gets corrected, not worked around. Ranking around a
stale label in your head leaves the next reader to make the same mistake — fix the label
instead of mentally overriding it.

## Type labels

`bug`, `enhancement`, `documentation`, and `chore` are the issue types. The forms under
`.github/ISSUE_TEMPLATE/` apply one at filing time: `bug_report.yml` applies `bug`,
`feature_request.yml` applies `enhancement`, and `task.yml` applies `chore`.
`documentation` has no form of its own (`config.yml` disables blank issues), so triage
applies it by hand to a documentation-only issue.

`ci` and `dependencies` are PR-only and never used for issue triage:
`.github/workflows/pr-label.yml` labels a pull request from its Conventional Commits
title type (`ci:` → `ci`, and likewise `feat:`/`fix:`/`docs:` → `enhancement`/`bug`/
`documentation`), and Dependabot applies `dependencies` to its own pull requests.

There is no `security` label. A vulnerability is never filed as a public issue: it goes
through `SECURITY.md`'s private reporting route (GitHub Security Advisories), which the
issue chooser's `config.yml` also links to.

`chore`, `ci`, `on hold`, and the `priority:`/`blocked:` labels are not GitHub defaults,
and GitHub silently drops a label a form applies when the repository does not have it.
`just labels` (`scripts/sync-labels.sh`) creates or updates every label in
`.github/labels.yml` on the live repository and never deletes one; running it is a
remote write that needs a human's sign-off (`AGENTS.md`'s "Security and human
approval").

`.github/labels.yml` is the source for the label set itself — name, color, and
description; this skill holds only what each one _means_ for triage. A label is added
or renamed there first, then here. If the file and this skill disagree about a label,
fix the mismatch rather than choosing one.

## What an issue body must contain

Two things belong in the body because nothing else can recover them later:

- **What is wrong today**, with a `path:line`. A description of a symptom without a
  location forces whoever picks up the issue to re-find what the filer already knew.
- **What observable result closes it**, named as a test or a command (`just test`,
  `just lint`, a `grep` that must print nothing) — not as a feeling of doneness ("works
  correctly", "is cleaned up"). A closing condition that cannot be checked mechanically
  cannot be verified by anyone but the filer.

## Ordering constraints

Write an ordering constraint as `Depends on #12`, one per line under a
`## Dependencies` heading, with `Blocks #N` for the reverse edge. This is the spelling
automation parses; prose like "after the guard work lands" is not machine-readable and
will not be picked up.

An issue carrying a `Depends on` line also carries `blocked: dependency` while the
blocker is open. The label is **not** removed automatically when the blocker closes:
whoever lands the blocking issue clears `blocked: dependency` by hand from every issue
that named it. Do not assume the label update is someone else's automated job — it is
a manual step in the same PR or a prompt follow-up that closes the blocker.
