# Verification 1: which Chromium-based apps expose a usable accessibility tree

Answers #7. Runs made on 2026-09-22 with `just probe` (PR #23's `hintjump-probe`),
`--scope focused --strategy batched`, from a process holding the Accessibility grant,
on macOS 26.5.2. Element counts are for the focused window only; a `dump` also walks the
menu bar under `--scope app`, which is why those counts are larger.

| App | Version | Chromium / Electron |
|---|---|---|
| Slack | 4.51.180 | Chrome 150.0.7871.114 / Electron 43.1.1 |
| Claude Desktop | 2.2553.1 | Chrome 152.0.7977.76 / Electron 44.2.0 |
| Visual Studio Code | 1.135.0 | Chrome 148.0.7778.280 / Electron 42.8.1 |
| Google Chrome | 152.0.7977.84 | — (baseline) |
| Safari | 26.5.2 | — (baseline) |

**Caveat on "untouched".** The machine these runs were made on already had several
Accessibility clients enabled (a password manager, a voice-input tool, two AI
assistants). Chromium builds its tree when it detects an assistive client, so "before
wake" below means "before *this probe* set anything", not "with no client on the
machine". The relaunch runs at the end are the closest this machine can get to a clean
state, and they show the same thing.

## Slack

Window open on a private channel with a few messages.

| Area | Before wake | After wake | Persists | Side effects |
|---|---|---|---|---|
| Message list | Exposed: one `AXList` (`AXContentList`) per day group, each message's links (`AXLink`, `AXPress`), "message actions" buttons | Same | Same in the same process; after ⌘Q + relaunch, exposed again on the first `dump` with no wake (333 elements) | None seen (CPU flat) |
| Composer | Exposed: `AXTextArea` with `AXPress`, description carries the placeholder | Same | Same | None |
| Sidebar channel list | Exposed: `AXRow` / `AXOutlineRow` per item, each with `AXPress`; the search field as `AXTextField` / `AXSearchField` | Same | Same | None |
| Top bar buttons | Exposed: `AXButton`, `AXPopUpButton`, `AXToggleButton`, all with `AXPress` | Same | Same | None |

Summaries: before wake `elements=344 duration=109.26ms`, 110 rows with `AXPress`; the
`wake` set call **succeeds** (no error); after wake `elements=344`, 110 rows with
`AXPress`. After relaunch, first `dump` `elements=333`, second `elements=334`, 104 rows
with `AXPress` both times. Reading `AXManualAccessibility` back answers `0` before and
after the successful set, and after relaunch.

Noteworthy for the target-count verification (#10): 72 of the 344 elements report a
frame 2 pt high — off-screen items of the virtualised message list, splitters, and
placeholder images. They carry real actions (`AXPress`), so a frame filter is needed
before counting them as targets.

## Claude Desktop

Window open on a long conversation. This is the app the probe itself ran from, so its
transcript changed between runs; the "after wake" growth is content, not exposure.

| Area | Before wake | After wake | Persists | Side effects |
|---|---|---|---|---|
| Transcript | Exposed: `AXWebArea` → `AXDocumentArticle`, `AXStaticText`, `AXList`, code blocks as `AXCodeStyleGroup`, links as `AXLink` with `AXPress` | Same | Same in the same process (relaunch not tested: the session ran inside this app) | None seen (CPU flat) |
| Composer and its buttons | Exposed: `AXTextArea` (description "Prompt"), `AXButton`s with `AXPress` for send, model, attach | Same | Same | None |
| Sidebar conversation list | Exposed: `AXButton` per conversation with `AXPress`; sidebar toggle, back/forward buttons | Same | Same | None |

Summaries: before wake `elements=701 duration=156.22ms`, 61 rows with `AXPress`; the
`wake` set call **succeeds**; after wake `elements=702`, 125 rows with `AXPress` (the
transcript had grown). `AXManualAccessibility` reads back `0` throughout.

## Visual Studio Code

Included because it was open and is the third Electron app the first user runs daily.

| Area | Before wake | After wake | Persists | Side effects |
|---|---|---|---|---|
| Editor, explorer, activity bar, status bar | Exposed: `AXOutlineRow`s for the explorer, `AXTabButton`, `AXButton`, `AXToolbar`, `AXList`, all with `AXPress` where clickable | Same | Same in the same process; after ⌘Q + relaunch, exposed again on the first `dump` with no wake | None: watched by eye through three consecutive `wake` + `dump` runs, no repaint, flicker, or focus ring; renderer CPU 0 % |

Summaries: before wake `elements=647 duration=122.58ms`, 125 rows with `AXPress`; the
`wake` set call **succeeds**; after wake `elements=647`, 125 rows. After a relaunch by
the user: first `dump` `elements=680`, second `681`, 125 rows with `AXPress`.

### The relaunch runs that settle "is wake needed at all"

VS Code was quit with `osascript … quit` and relaunched with `open -a`, twice.

1. Polled from the moment the window answered: `t+1s elements=12`, `+1s 13`, `+3s 653`,
   `+6s 673`, `+10s 673`. The first two reads are the window chrome while the workbench is
   still loading; nothing was set.
2. Relaunched again, then **12 s of silence with no Accessibility call at all**, then
   the first `dump`: `elements=672`; the next two: `673`, `673`.
   `AXManualAccessibility=0`, `AXEnhancedUserInterface=0` on the application element.

So on this machine the tree is complete on the very first read, in a freshly launched
process, with neither attribute set by anyone.

## Baselines: Safari and Chrome

Both on the same content-heavy page (a GitHub issue).

| App | Summary | Links | Buttons | Headings |
|---|---|---|---|---|
| Safari | `elements=413 duration=157.50ms`, 72 rows with `AXPress` | 43 `AXLink` | 25 `AXButton` | 20 `AXHeading` |
| Chrome | `elements=625 duration=124.03ms`, 149 rows with `AXPress` | 51 `AXLink` | 59 `AXButton` | 22 `AXHeading` |

Chrome answers `attribute unsupported` for `AXManualAccessibility` (it is an Electron
attribute, not a Chromium one) and exposes the page anyway. `AXEnhancedUserInterface`
reads `0` on both browsers. The Electron apps' trees look like Chrome's, not sparser.

## Step 5: `AXEnhancedUserInterface`

Not exercised. Step 2 exposed everything, and reading the attribute showed it was `0`
on every app throughout, so nothing here depended on it.

## What this means

- **Chromium-based apps are usable as they are.** Slack, Claude Desktop, and VS Code all
  expose their chat areas, composers, sidebars, and buttons with roles, frames, and
  `AXPress`, on the first read, in a fresh process, with no attribute set. The first
  release can put hints on them.
- **`AXManualAccessibility` is a no-op here, but harmless.** The set succeeds on all
  three Electron apps and changes nothing observable — not the element count, not the
  read-back value, not CPU, not the screen. It is unsupported on Chrome and on native
  apps, which the reader already reports as a distinct error. Because other Accessibility
  clients were present, this machine cannot prove the tree would also be complete on a
  Mac with no other client; the cheap insurance is to set the attribute once per process
  when a read finds an `AXWebArea` with no children, rather than always.
- **Nothing persists and nothing needs to.** The attribute reads `0` after set and after
  relaunch; exposure did not depend on it, so there is no persistence rule to implement.
- **Two things for the next verifications.** Chromium trees are deep (the composer sat at
  depth 24–32) and carry many 2 pt-high off-screen elements with real actions; the
  target-count decision (#10) needs a visible-frame filter, and the read-latency
  verification (#8) should include Slack, whose 344-element window read in ~100 ms
  batched — far under Finder's 2060-element, 3.4 s window.
