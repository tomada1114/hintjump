# Cost discipline

What this skill keeps out of the main context, why the run count is what it
is, and why each spawn gets the tier it gets. Read it when deciding whether
to delegate a step, before changing a run count, or before picking a
`/code-review` effort.

## Table of Contents

- [Code review effort](#code-review-effort)
- [What the startup costs](#what-the-startup-costs)
- [Run budget](#run-budget)
- [Model and effort assignment](#model-and-effort-assignment)
  - [Effort comes from the agent definition](#effort-comes-from-the-agent-definition)
  - [When implementation goes to `architect`](#when-implementation-goes-to-architect)
  - [The floor: too small to delegate](#the-floor-too-small-to-delegate)
- [What parallel mode costs](#what-parallel-mode-costs)

The main context holds the selection and the verdicts, nothing else. Issue
bodies go to the triage agent, diffs stay in the sub-agent run that produced
them, CI logs and verify output reach the parent through a file rather than
through the prompt. If you find yourself about to read a full GitHub API JSON
blob, a workflow log, or an unrelated part of a diff in the main context,
that is the signal to delegate or scope the read instead.

Labeling is the cheap half of this by design: the backfill is a pure script
pass with a one-line summary, and re-deriving priority from issue prose
happens once per issue — ever — because the answer is written back to GitHub.
On a labeled backlog the whole ranking step is `--select`, three lines, no
spawn at all. Never re-read bodies to reconstruct a priority a label already
carries; if a label looks wrong, fix the label.

## Code review effort

Only for [step 4](../SKILL.md#4-review-the-branch)'s local pass.

`/code-review <effort> <branch> --fix` forks and runs entirely outside this
session's context — the finders' reads never reach here, only the findings
do. Effort controls how much of that runs:

**`low` is this repository's default effort.** The user set it as the standing
choice for every review this skill runs; use it unless the row below genuinely
calls for more, and do not silently drift back to `medium` because a diff looks
large.

| effort | pipeline | when |
|---|---|---|
| `low` | one pass, no verify sub-pass, ≤4 findings, skips test/fixture hunks | **the default** — use it unless a row below applies |
| `medium` | 8 finder angles × 6 candidates, 1-vote verify, ≤8 findings (precision-biased) | reach for it only deliberately: a change whose blast radius is hard to see from the diff alone, or one the run has already had to repair once |
| `high` | same 8 angles, 1-vote verify biased toward recall, ≤10 findings | the change can lose or corrode data that already exists — a migration, a storage-layer write, a released public contract real consumers are on — or the user asked for one |

Diff size or file count alone is not a reason to escalate — `low` already reads
the whole diff for scope and correctness, and a big mechanical rename is
exactly the shape it handles well. Never `ultra`: it runs in the cloud, is
billed per use, and the prompt that defines it says explicitly that a model
cannot launch it itself.

### The escalation that is not optional: a diff `low` cannot see

`low` **skips test and fixture hunks**. That is right for an ordinary test — it
follows the behavior the code already fixed. It is wrong whenever the file under
`tests/` *is* the gate rather than a consumer of one, and it fails silently: a
diff confined to such a file comes back `(none)` in a few seconds, which reads
exactly like a clean review and is not one.

Before accepting any `low` verdict, ask what the review actually read:

- **Every hunk in the diff is in a test or fixture file → `low` reviewed
  nothing.** Escalate to `medium`. Judge the file by its *role*, not its path: a
  file under `tests/` that lints workflow YAML, asserts zone or import
  boundaries, walks the tree for secrets or placeholders, or otherwise decides
  what "green" means is a gate, and a hole in it is a hole in every future
  change.
- **A clean verdict that names what it skipped is not a clean verdict.** A
  result like "the entire diff is confined to X, which this review level skips"
  is the review telling you it abstained. Read the sentence, not the empty
  findings list.
- A run that escalated for this reason says so in the step 10 report, with the
  reason — otherwise it looks like drift away from the standing `low` default.

Observed cost of getting this wrong: a gate change reviewed at `low` returned no
findings; re-run at `medium` it returned four, all reproduced against the
branch, one of them a security rule that silently accepted three of the four
YAML spellings it existed to reject.

## What the startup costs

Steps 0 through 2c are one `plan.py` call and one `gh` fetch pair — preflight,
ranking, selection, repo profile and grouping in a single block. Two things keep
it there, and both are easy to undo by accident:

- **The digest cache.** Every `issue_digest.py` call inside the same few minutes
  reads the fetch the plan already paid for; `--issue`, `--detail` and
  `--body-chars` all filter data already in hand rather than re-fetching it.
  What breaks this is asking the same question in three calls — a `--select`,
  then a `--rank-only`, then a list of `--issue` numbers — which is what
  `--with-rank` and `--detail-top` exist to collapse. Pass `--refresh` only
  after this run changed the backlog; passing it habitually turns the cache off.
- **The reference files.** `dependency-triage.md` and `worktree-parallelism.md`
  are ~380 lines between them and are *not* hot-path reading any more. The plan
  answers what they used to be read for; open them when it says `PARTIAL`, when
  a gate fails, or before cleanup — not on every run.

The one thing worth spending on at startup is `issue_digest.py --detail-top K`
when the picked issues' bodies genuinely have to be read. That is still one
call, and it is bounded by K.

## Run budget

Run count scales with issue count, not with thoroughness: one triage spawn
(optional), one implementation sub-agent per issue plus up to 2 resume/patch
runs when this session's judgment finds the first incomplete, one
`/code-review` per branch, in parallel mode one fix sub-agent per branch that
had accepted findings (none when a review came back clean), one repair
sub-agent per failing CI attempt (capped at 3). This session's own
judgment calls — reading the implementation diff, reading `--fix`'s diff,
deciding what CI failure means — cost targeted reads in this context, never a
spawn. Filing a follow-up (step 8) never adds a run either: whatever found it
already returned the lead under `FOLLOW-UPS`, and confirming it costs a
couple of targeted reads.

Two things scale that count beyond the issue list itself, both deliberately
bounded:

- **Background design agents (step 8b)** — one `architect` run per design-blocked
  issue, capped at 3 in flight. They cost nothing in wall-clock on the shipping
  path (nothing ever waits on one) and almost nothing in this context: what
  comes back is a verdict and a two-line approach, while the design itself goes
  to the issue. What they buy is a backlog that stops accumulating undecided
  work — the single most expensive thing a backlog can hold, because every
  future ranking pass re-reads it and skips it again.
- **Shipping the run's own follow-ups (step 8c)** — a full steps 3–8 cycle per
  follow-up, the same cost as any issue. This is why depth is capped at 1: a
  run that shipped what it filed, and then what *that* filed, has no
  termination condition and no budget the user agreed to. Depth 1, then stop
  and report.

## Model and effort assignment

<!-- derived from orchestrating-models §2 -->
One model, two tiers. Every spawn in this skill runs on Opus 5.5, and the tier
is its effort: **`executor`** (Opus 5.5 `low`) and **`architect`** (Opus 5.5
`high`), both defined in this repository's `.claude/agents/`. The main session
runs at `medium`; there is no `medium` sub-agent, because anything this session
would hand to one it can do itself at the same quality and price, without the
handoff.

The dividing line is **how settled the spec is**, not the kind of work.

| Spawn | Tier |
|---|---|
| Implementation (step 3) | `executor` by default; `architect` when [the architect test](#when-implementation-goes-to-architect) holds |
| Priority research (step 1) | `architect` — it only spawns when the ranking is tangled or close, which is a judgment call by construction |
| Review fix run (step 4, parallel mode) | `executor` — the findings are already read and accepted, so the fix is specified |
| `/code-review` fallback (step 4) | `architect` — a review whose verdict is the deliverable |
| CI repair (step 6), attempts 1–2 | `executor` |
| CI repair, once the same failure has survived two attempts | `architect` — persistent failure means the spec or the fix needs judgment, not another mechanical retry |
| Design decision (step 8b) | `architect` — deciding an approach nobody has decided; a bad call recorded on an issue outlives the run that made it |

No other model is used. On Artificial Analysis's Intelligence Index v4.3.2 ×
Cost per Task (2026-09-22), Opus 5.5 `low` (42 at $0.55), `medium` (51 at
$1.34) and `high` (54 at $1.82) are each the cheapest option in their Index
band; every Fable 5.1 and Opus 5 setting is beaten by an Opus 5.5 setting at
the same or lower cost (Fable `high` 51 at $3.91 ties Opus 5.5 `medium` at
$1.34), and Sonnet 5 `low` saves $0.04 over Opus 5.5 `low` for 24 against 42.
`xhigh` and `max` are not used for spawns: `high` → `xhigh` buys 2 points for
$1.64, five times the marginal price of `medium` → `high`.

### Effort comes from the agent definition

The Agent tool takes a `model` but not an `effort`, so the tier has to come
from somewhere else: spawn with `subagent_type: executor` or
`subagent_type: architect`, whose frontmatter pins `model: claude-opus-5-5`
and `effort: low` / `high`. **Never spawn with a bare `model: opus`** — it runs
at whatever effort the session's `modelSettings` gives Opus 5.5 — `medium` when
it matches the main session — which is neither tier. A Workflow script's `agent()` takes
`model` and `effort` directly; pass the same pair.

### When implementation goes to `architect`

Most of a backlog is `executor` work: bug fixes, removals, mechanical rewrites,
config edits, documentation that follows a shape already settled, another
instance of a pattern the repo already has, and any issue whose Done-means is
a command that passes. Spawn the step 3 implementation on **`architect`** when
either test below holds.

**Blast radius — what the backlog builds on.** Some issues are not "fully
specified work with a clear pass/fail" even when their body is excellent,
because what they produce is a **shape other issues copy** rather than a
behavior a test pins down:

- **Architecture or a skeleton** — the directory layout, the app/router
  skeleton, the composition root, a zone or module boundary.
- **An interface, port, or schema** — a public contract, an adapter boundary,
  an error taxonomy, a data shape. The first implementer fixes the vocabulary
  every later one inherits.
- **A skill, instruction file, or gate design** — a `SKILL.md`, `AGENTS.md`,
  `CLAUDE.md`, a lint rule that encodes a convention, a CI job that defines
  what "green" means. These are prompts and policies: they are read by every
  future run, and a mediocre one degrades work long after this run ends.

Would a wrong call here be cheap to correct in its own follow-up, or would it
be copied by every issue after it? Only the second qualifies.

**Difficulty — what `low` would get wrong.** A settled spec can still be hard
to carry out:

- the change spans several modules or layers and the edits have to agree with
  each other (a data shape threaded from storage through to the UI, a
  behavior change that moves several call sites at once);
- non-trivial logic — concurrency, caching or invalidation, a state machine,
  an algorithm whose edge cases the issue does not enumerate;
- the Done-means is settled but reaching it needs choices the body leaves
  open (which of two existing helpers to extend, where a new piece belongs).

If the implementer could plausibly come back asking what was meant, it
needed `architect`. An undecided *approach* is not this test — that is a
design block, decided at [step 2b](../SKILL.md#2b-decide-a-design-that-gates-the-pick)
or 8b before any implementation spawns.

Signals visible before spawning, straight off `issue_digest.py`: an
`unblocks×N` of 2 or more, a `foundation`/`schema`/`interface` signal, a
Done-means written as a structure to establish rather than a behavior to
observe, or a body that names three or more modules. Any one of those is a
reason to look; the two tests decide. A removal-only issue is `executor` even
when it is `P0` and unblocks the whole chain — deleting what a decision
already condemned carries no design in it.

The same tier applies to a resume/patch run: it inherits the tier the first
run used, because a change the first run got half-right is exactly where the
remaining judgment sits.

Implementation stays delegated even though the main session's default is to
do the work itself — a deliberate exception, bought for context isolation: the
diff and the repo exploration are never needed in the main context again once
this session has judged the result.

### The floor: too small to delegate

That exception buys context isolation, and an issue with almost no context to
isolate does not repay it. Below a certain size the handoff costs more than the
work: writing a self-contained prompt, waiting, reading the report, then
re-deriving enough of the diff to judge it — for a change this session could
have made and verified in a couple of commands.

Implement it directly when **all** of these hold:

- the whole change is a handful of lines in one or two files, and this session
  already knows which lines from the issue body or a finding it just read;
- there is no exploration to do — nothing to search for, no unfamiliar module
  to learn;
- the verification is a command whose output this session reads anyway
  (`pnpm audit`, one test file, the gate);
- it is not foundational by the blast-radius test above. A three-line change to
  an interface or a gate is still foundational — size is not the same question as blast
  radius, and this floor never overrides that section.

A dependency pin closing a named advisory, a one-line config fix a review
turned up, a stale reference in an instruction file: these are the shape. Say
in the step 10 report that the run implemented it directly, so the choice is
visible rather than looking like a skipped step.

Everything above that floor — anything with a file to find, a module to read,
or a test to design — stays delegated.

## What parallel mode costs

Parallel mode does not reduce the number of runs — the same issues need the
same implementations. What it changes is when they happen, and what has to be
set up first.

**Added, per issue in a parallel batch:** one dependency install and one
baseline verify (`worktree_setup.sh`), both outside this context — the parent
reads one `verdict:` line each. Plus, per branch with accepted review
findings, one `executor` fix run that serial mode gets for free from
`/code-review --fix`.

**Saved:** the implementations overlap instead of queueing, which is the
longest stretch of a run, and nothing in this context grows to pay for it —
each sub-agent's exploration and diff still stay inside its own run.

The break-even is group size. One issue in a group means paying the setup for
no overlap at all, which is why the plan refuses to parallelize a group smaller
than 2. The default cap of 3 comes from somewhere else entirely — rebase churn
as the default branch moves under the batch — not from cost, which is why
`plan.py --max-parallel` can raise it when the user asks for more and why
nothing else should. Every issue past 3 in a batch is another branch that has to
be brought forward after each merge in the batch, and that churn grows with the
square of the group, not with it.

A repo that fails the viability gate costs one worktree's setup to discover,
once per run. The answer is a property of the repository, not of any issue:
never re-test it per issue.
