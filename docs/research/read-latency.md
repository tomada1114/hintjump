# Verification 2: accessibility read latency against the 300 ms budget

Answers #8. Runs made on 2026-09-22 with `just probe time --scope focused --runs 10`
(PR #23's `hintjump-probe`; `--runs 5` for the two Finder rows that take 10–35 s per
read), from a process holding the Accessibility grant, on macOS 26.5.2, Apple silicon.
Wall-clock time is measured inside the adapter, from `AXUIElementCreateApplication` to
the completed snapshot. The window state did not change between the four strategies of
one window (element counts are identical where no pruning applies).

**Every window was brought to the front right before its runs.** A first attempt with
the target apps left behind other windows gave Safari `batched` p50 535 ms and System
Settings `batched` p50 696 ms — five times the numbers below — while Chrome, Slack, and
Finder were unchanged. Bringing the app forward restored the numbers at once (Safari
139 ms, System Settings 76 ms): an occluded app is throttled by App Nap and answers
Accessibility calls slowly. The product only ever reads the frontmost application, so
the front-of-screen numbers are the ones that count, and any future measurement has to
be taken the same way.

## Windows

| Window | App version | Elements (unpruned) |
|---|---|---|
| Safari, Wikipedia main page (238 `AXLink`) | 26.5.2 | 1070 |
| Chrome, the same page (245 `AXLink`) | 152.0.7977.84 | 1381 |
| Slack, a channel with a short message list (the longest available) | 4.51.180 | 334 |
| Finder, list view of `/usr/bin` (about 1,000 rows) | macOS 26.5.2 | 9408 |
| System Settings, Privacy & Security pane | macOS 26.5.2 | 242 |

## Results

p50 / p95 in milliseconds; "n" is the element count that strategy returned. The
target is **p95 ≤ 200 ms** on every window.

| Window | naive | batched | pruned | batchedPruned |
|---|---|---|---|---|
| Safari | 247 / 350 (n 1070) | 139 / 223 (n 1070) | 87 / 168 (n 336) | **54 / 126** (n 336) |
| Chrome | 336 / 409 (n 1381) | 139 / 202 (n 1381) | 374 / 436 (n 1381) | **185 / 243** (n 1381) |
| Slack | 64 / 136 (n 334) | 28 / 85 (n 334) | 74 / 128 (n 342) | **37 / 99** (n 342) |
| Finder | 31156 / 35089 (n 9408, 5 runs) | 9777 / 9836 (n 9408, 5 runs) | 100 / 150 (n 308) | **54 / 113** (n 308) |
| System Settings | 118 / 226 (n 242) | 73 / 160 (n 242) | 80 / 165 (n 209) | **48 / 121** (n 209) |

(Slack's pruned count is 342 rather than 334 because `AXVisibleChildren` on one
container answers a slightly different list than `AXChildren`; the difference is the
container's own bookkeeping, not lost targets.)

## What the numbers say

- **Batching halves the cost everywhere**, on every toolkit: one
  `AXUIElementCopyMultipleAttributeValues` per element instead of eight
  `AXUIElementCopyAttributeValue`s. It is a pure win with no change in what comes back
  (the local-machine test asserts `naive` and `batched` agree).
- **Pruning is what makes big native trees possible.** Finder's list view is the
  extreme: 9,408 elements, of which `AXVisibleRows` on the outline keeps 308, turning a
  10 s read into 54 ms. Safari's page drops from 1,070 to 336 by the visible-rectangle
  test alone, because WebKit reports honest frames for scrolled-away content.
- **Pruning does nothing on Chromium, and costs.** Chrome's count stays 1,381 under
  `pruned`, and `pruned` is *slower* than `naive` (374 vs 336 ms p50): the adapter asks
  `AXVisibleRows` / `AXVisibleChildren` per element, Chromium supports neither on its
  groups, and each refusal is still a round trip. It prunes nothing by rectangle
  because Chromium clips scrolled-away content to slivers at the visible edge instead
  of reporting where it really is: 1,046 of Chrome's 1,381 elements report a frame
  0–2 pt tall, and 7 fall outside the window by y. Slack (also Chromium) shows the
  same in miniature. WebKit and AppKit report real frames; Chromium reports clipped ones.
- **The only miss is Chrome, at p95 243 ms** with `batchedPruned` (202 ms with plain
  `batched`, which is the same 1,381 elements without the wasted visible-children
  calls). Safari, Slack, Finder, and System Settings all clear 200 ms with room.

### The strategy

`batchedPruned`. It is the fastest on four of five windows, within 40 ms of the fastest
on the fifth, and the only one that survives Finder. Chrome's miss is not a reason to
pick `batched`: batching alone leaves Finder at 10 s.

The read-time budget is **p95 ≤ 200 ms** for the read alone, leaving 100 ms of the
300 ms trigger-to-hints budget for ranking, label assignment, layout, and one frame of
drawing.

### What the Chrome tree looks like, for the follow-up

Depth 23. Roles: 546 `AXStaticText`, 419 `AXGroup`, 245 `AXLink`, 49 `AXButton`,
32 `AXList`. 1,046 of 1,381 elements carry a frame no taller than 2 pt: they are the
scrolled-away page, clipped rather than positioned. Two adapter-side moves would each
take Chrome under the target, and neither is a product decision:

1. Ask for `AXVisibleRows` / `AXVisibleChildren` inside the one batched call, or only on
   the roles that publish them (`AXTable`, `AXOutline`, `AXList`), instead of a separate
   call per element. That alone recovers the 40 ms `pruned` costs over `batched` on
   Chromium (243 → ~200 ms).
2. Treat a frame no taller or wider than 2 pt as outside the visible rectangle, so the
   walk skips the subtree under a clipped element the way it skips one that WebKit
   places off screen. On this page that is 1,046 of 1,381 elements — the same cut the
   rectangle already makes on Safari (1,070 → 336).

Both are translation: "where does the application say this element is, and does that
intersect the window" — the same question the rectangle prune already asks.
