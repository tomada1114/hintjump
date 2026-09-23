---
name: filing-feedback
description: >
  Covers turning the owner's report of something that bothers them in the running app —
  screenshots, a dictated or loosely worded note, a side-by-side comparison with another
  app — into GitHub issues: separating each observation, checking whether the screenshot
  came from a stale build, locating it in the code and in docs/decisions.md, telling a
  defect from a decision being revisited, asking the owner only what they must decide,
  and filing a parent issue with sub-issues. Use when the owner says something looks
  wrong, off, cluttered, or worse than another app, pastes screenshots of the overlay,
  or asks for issues to be filed from what they noticed while using Hintjump.
---

# Filing Feedback

**Owns:** getting from the owner's report of what bothered them in use to filed issues
that someone can ship without the owner: the analysis, the questions, the split, and the
filing itself. **Does not own:** the label taxonomy and what an issue body must contain
(`triaging-issues`); implementing what was filed (`shipping-issues`, `tdd`); launching
the app to reproduce something (`running-the-app`).

The owner reports what they felt, not where it comes from: "labels look shifted",
"something shows up twice", "the other app is easier to read". The job is to turn each
feeling into a located cause and a decided fix, and to file it. Filing is the default
outcome. Start implementing only when the owner asks for it in the same request.

## 1. Split the report into observations

List each thing the owner saw as its own line, stated concretely enough to check: which
label, which element, which app, and where on the screenshot. A single sentence often
holds two observations ("shifted, or maybe shown twice"). A screenshot often holds more
than the owner named. Read every image, including the reference app's, and note both
what the reference does better and what it does that this app should not copy.

## 2. Check which build the screenshot came from

A screenshot of the running app shows whichever build was launched last, not `main`.
Compare the process start time with the latest merge before treating anything as a
current defect:

```bash
ps -axo pid,lstart,command | grep -i "[H]intjump.app"
git log -1 --format='%ci %s' main
```

If the build predates recent fixes, name those fixes in the issue. Include confirming
against `main` in the approach, using a read-only probe or a unit test fixture. Never
make "the owner reshoots it" a step.

## 3. Locate and classify each observation

For each observation, find the code that produces it (`path:line`) and the entry in
`docs/decisions.md` that governs it. Then put it in one of these classes:

| Class | What it means | What to file |
|---|---|---|
| Defect | The code disagrees with a recorded decision or with the owner's evident intent. | A `bug` issue |
| Decision revisited | The code does what `docs/decisions.md` says, and the owner now wants something else. | An `enhancement` whose done-criteria amend that decision |
| Already fixed | Fixed on `main`, and seen only because the build was stale. | Nothing. Say so in the report |
| Non-goal | Listed under `AGENTS.md`'s "Product" › Non-goals. | Nothing. Name the non-goal back to the owner |

Evidence that needs no one's hands is fair game: reading the code, a read-only
`just probe dump`, a unit test. Anything on the last rung of `AGENTS.md`'s "How far
verification goes" is not part of filing.

## 4. Ask only what the owner must decide

Bundle every open choice into one `AskUserQuestion` call (Codex CLI: one message with
numbered options). Put a recommendation first, and give an ASCII preview for any visual
choice, such as where a label sits or how it looks. Typical questions:

- **A design direction.** Explain what the current decision was for, so the owner
  reverses it knowingly.
- **How to split the work into issues.**
- **Anything ambiguous in a dictated note.** Transcription errors are common, so ask
  rather than guess.

Do not ask what the code or `docs/decisions.md` already answers. Read the answers in
full: they can change the plan or add new work to the same request.

## 5. File

Follow `triaging-issues` for labels, priority, the body, and the close condition. Its
"A close condition an agent can meet alone" section applies to every issue filed here.
Also:

- **One coherent change per issue.** For more than one issue, file the children first,
  then a parent that lists them, and link them as sub-issues:

  ```bash
  id=$(gh api repos/<owner>/<repo>/issues/<child> -q .id)
  gh api -X POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id="$id"
  ```

- **Order children that edit the same files or reference images** with a
  `Depends on #N` line and `blocked: dependency`, so they do not conflict when shipped
  in parallel.
- **Add a ship contract** (`shipping-issues`' `references/ship-contract.md`) to every
  issue, with an honest `touches=`.
- **Write for a public repository.** Write in English, and describe another product as
  "a comparable app" rather than by name. Never upload the owner's screenshots. They
  show their sessions, tabs, and accounts. Describe what they show instead.
- **Link the issues that own the same decision.** For example, the design spec port that
  must follow an amended decision.

Filing an issue is a remote write (`AGENTS.md`'s "Security and human approval"). An
explicit request to file issues authorizes it. A report without one gets the analysis
and a proposed issue list first.

## 6. Report back

Report in the language the owner wrote in, and cover:

- **What was filed, with links.** Include the decision each issue carries.
- **What was not filed, and why.** For example, already fixed on `main`, a non-goal, or
  not a defect.
- **Which observations came from a stale build.**
