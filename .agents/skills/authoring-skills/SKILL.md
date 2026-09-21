---
name: authoring-skills
description: >
  Covers how a skill in this repository is authored under .agents/skills/, mirrored into
  .claude/skills/ by scripts/sync-agents.sh, and checked so a malformed SKILL.md does
  not silently fail to load. Use when adding, editing, or reviewing a SKILL.md, running
  just agents-sync or just agents-check, deciding whether new material belongs in
  AGENTS.md or a new skill, or investigating why a skill never fires in Claude Code or
  Codex CLI.
---

# Authoring Skills

**Owns:** how a skill in this repository is authored, mirrored, and kept from silently
failing to load. **Does not own:** how a script under `scripts/` is written (`AGENTS.md`'s
"Repository scripts"); a change to the gate files that run the mirror check
(`changing-gates`); which documentation surface a change lands on (`updating-docs`); the
content of any individual skill.

## The single source of truth

- Author every skill once, under `.agents/skills/<name>/` — the path Codex CLI discovers
  project skills from. `scripts/sync-agents.sh` mirrors that tree into
  `.claude/skills/`, the only path Claude Code reads.
- Both copies are real, committed files. A symlink would work from this checkout but not
  from a fresh clone on every platform, and Codex follows a linked directory into its
  own subdirectories, registering a nested `SKILL.md` as a second, nameless skill.
- Loop: edit the `.agents/` copy, run `just agents-sync`, commit both sides. Never
  hand-edit anything under `.claude/skills/` — the next sync overwrites it silently
  (`rsync -a --delete`), and a hand edit there drifts from the source it should mirror.
- Drift between the two trees fails `scripts/sync-agents.sh --check`, which compares the
  trees byte for byte with `diff -r`, not just a spot-check of `name`. It runs as
  `just agents-check`, inside `scripts/lint.sh` (so `just lint` and CI's `lint` job), and
  in the pre-commit hook's "Skills mirror" section, which checks the staged versions of
  both trees whenever a commit stages a path under either one.

## Layout

- Exactly one directory level under `.agents/skills/`: `.agents/skills/<name>/SKILL.md`
  plus optional reference, script, or asset subdirectories beneath that same skill
  directory. No category subfolders — both hosts and the mirror assume one path segment
  between the skills root and the skill's own files.
- No file below a skill root may itself be named `SKILL.md`. A nested one registers as a
  second, nameless skill in both hosts. Name reference files for their content instead
  (`failure-modes.md`, not another `SKILL.md`). Nothing checks this yet.
- No symlinks anywhere under either tree. `scripts/sync-agents.sh` refuses a symlink in
  the source tree, and a `.claude/skills` that is itself a symlink, with
  `ERR_AGENTS_SYMLINK`.

## Frontmatter

Exactly two keys, `name` and `description`, with `description` written as a folded
block scalar (`description: >`) as every skill here does. Do not add any third key — no
`paths`, no `globs`, no host-specific extension. Claude Code's own `paths` field would
gate auto-invocation on a glob, but Codex CLI has no such field: it ignores an unknown
key and matches only on `description`. The same skill would then auto-fire on different
terms per host, so a portable skill keeps `description` as its one trigger surface.
(`.claude/rules/*.md` do use `paths:` — they are Claude Code-only and are not skills.)

- `name` is byte-identical to the directory name: lowercase letters, digits, and
  hyphens.
- English only, per `AGENTS.md`'s "Important Reminders".
- The description is a retrieval string describing the situation that should load the
  skill (file globs, command names, error strings, decisions), never a summary of the
  skill's internal workflow. Both hosts select a skill on the description's _meaning_,
  so a trigger keyword mirrored into another language buys nothing.
- Keep the description well under the 1,024-character limit of the Agent Skills format;
  the ones here run 330-570 characters.

None of these rules is checked mechanically yet — see "Why this needs its own test"
below.

## When a new skill is warranted

Add a skill only for work that recurs and needs a workflow, local references, or policy
loaded on demand — not for a fact stated once. Extend an existing skill instead of
creating a near-duplicate when the new material is a variant of what that skill already
covers.

One home per rule: a rule stated in both `AGENTS.md` and a skill costs context twice and
the two copies drift apart. The one exception is a prohibition an agent needs even while
its own declared task is something else entirely (for example, never lower the coverage
floor or weaken a gate to make a run pass) — that stays in `AGENTS.md`, where every agent
reads it regardless of task, and a task-specific skill holds only the reasoning an agent
doing that task needs. `changing-gates` shows the pattern: it points at `AGENTS.md`'s
"Security and human approval" for the prohibition rather than restating it.

Every new skill opens with an ownership block (`**Owns:**` / `**Does not own:**`) naming
what it decides and which sibling decides the adjacent question. `create-pr`,
`smart-commit`, and `tdd` predate the convention. Cross-reference a sibling skill by its
name in backticks, never by path, and an `AGENTS.md` rule by its section name in quotes
(`AGENTS.md`'s "Repository scripts"), never by line number — line numbers go stale the
first time the file above them changes.

Do not write down what a config already enforces. Name the gate in one line
(`Enforced by: <file> "<setting>".`) and spend the skill's words on the judgment the
config cannot express — the same principle `AGENTS.md` states for itself.

A skill added, renamed, or deleted gets its row in `AGENTS.md`'s Skills table updated in
the same commit, and widening a skill's subject means widening its row.

## Size and structure

- Target 150 body lines per `SKILL.md`, never exceed 200.
- A `references/*.md` file stays under 400 lines and is linked with a relative path one
  level deep, never with `@` and never as an absolute path.

## Spell-check and formatting

`typos` runs in `scripts/lint.sh`, but it skips hidden paths by default and `typos.toml`
does not turn that off, so neither `.agents/skills/` nor `.claude/skills/` is
spell-checked today (`typos --files` lists neither tree). Proofread a new or edited
`SKILL.md` yourself. When a technical term has to be allowed later, add it to
`typos.toml`'s `default.extend-words` rather than working around the checker.

Markdown has no auto-formatter here: `just fmt` runs SwiftFormat on Swift files only, so
a `SKILL.md` is formatted by hand and reviewed by eye. Wrap prose at the width the
neighboring skills use.

## Scripts bundled inside a skill

A script shipped under `.agents/skills/<name>/scripts/` follows `AGENTS.md`'s
"Repository scripts" section exactly like one under `scripts/`: `#!/usr/bin/env bash`
with `set -euo pipefail`, bash 3.2-compatible, `shellcheck`-clean (`scripts/lint.sh`
checks every tracked `*.sh`, at any depth), the `ERR_<STAGE>_<WHAT>` failure contract,
and a test under `scripts/tests/` built on `scripts/tests/lib.sh`, which
`scripts/tests/run.sh` (`just test-scripts`) runs. Keep it a thin dispatcher; anything
with real branching logic belongs in `scripts/`, where it is easier to find and test.
No skill ships a script today.

## Why this needs its own test

`scripts/sync-agents.sh --check` only proves the two trees are byte-identical; it says
nothing about whether the source tree is well-formed. It is the only skills check that
exists, whether reached through `just agents-check`, `just lint`, CI's `lint` job, or the
pre-commit hook. A `SKILL.md` whose frontmatter fails to parse, whose `name` disagrees
with its directory, whose frontmatter carries a stray key, or which sits in a nested
directory passes that check, mirrors cleanly, and simply never loads in either host —
nothing reports it. Nothing checks that `AGENTS.md`'s Skills table matches the
directories under `.agents/skills/` either. Issue #25 adds those checks; until it lands,
read the frontmatter yourself, and before committing a new or changed skill run:

```bash
just agents-sync
just agents-check
```
