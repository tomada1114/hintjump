# Verification 4: how many targets a window holds, and how often the wanted one gets a single character

Answers #37. Reads made on 2026-09-22 with `just probe dump --app <bundle id> --rank`
(the probe's defaults: `--scope focusedWindow`, `--strategy naive`) from `main` at
`07ed83c`, on macOS 26.5, one 2560×1440 display plus a second display. Each read ranks
the window with the shipped `TargetRanker` and its `FirstCutTiers`, and prints every
element's rank and tier, or why it is not a target. App versions were not recorded.
Titles, message text, file names, and page text are left out of this note on purpose;
elements are described by role and place only.

**This deviates from the issue's method.** The issue asks for about 30 logged clicks,
each with the rank the wanted element had. The owner declined a click-logging session
and instead named, per app, *what* they click. So the hit rate below is computed per
**category**: for each window, every element in a wanted category is found from its
role, subrole, frame, and position in the tree, and the table reports what share of
them ranks within N. A category counts each click destination once — a Finder file
whose row, cells, and name field are all targets is one item, hit when the best-ranked
of them is within N. Categories come from two sources, and the tables say which:

- **Logged** (the owner's own words): in Safari and Chrome, article links and tabs —
  not ads and not the site's navigation bar; in VS Code, the explorer's files and
  folders; in Claude Desktop, the sidebar's conversations, the New chat button, and the
  settings button.
- **Assumed** (the owner did not say; typical targets chosen for this note): Slack's
  sidebar rows and thread reply buttons; Finder's sidebar locations and list-view rows;
  System Settings' sidebar panes and the open pane's controls; Obsidian's file list.

A category share is not a per-click hit rate: it weighs every item in the category
equally, where real clicks favor a few. It says whether the ranker puts the *kind* of
thing the owner clicks where the singles are.

**Every window was read while its app was frontmost.** Safari exposes no web content to
the Accessibility API while it is in the background — the same window read from behind
gave 29 elements, the toolbar and nothing of the page, and setting
`AXManualAccessibility` did not change that. The product only reads the frontmost
application, so this costs it nothing, but a measurement taken from behind would.

**The reads are `naive`, the product reads `batchedPruned`.** Pruning skips subtrees the
application reports off screen or clipped to a sliver; the ranker's filter already
excludes an element whose center is outside the window or whose frame is under 8 pt,
so the targets should be the same, but this was not checked element by element here
(`docs/research/read-latency.md` › After the Chromium fixes checked it for pressable
elements on Safari and Chrome).

## Windows

| Window | What was open | Size (pt) |
|---|---|---|
| Safari | a news portal's top page, one tab (so no tab bar) | 1266 × 1073 |
| Chrome | the same page, ten tabs, bookmarks bar shown | 1280 × 1410 |
| Slack | a channel with a few messages; workspace rail, sidebar, empty composer | 1389 × 1410 |
| Claude Desktop | a conversation opened in its own window, which has no sidebar | 1710 × 1073 |
| Finder | list view, sidebar shown | 1146 × 1073 |
| System Settings | a pane of navigation rows, sidebar shown | 723 × 926 |
| VS Code | the explorer sidebar open on a folder tree, a terminal panel open | 2560 × 1410 |
| Obsidian | a note open, the file list collapsed (only the icon ribbon at the leading edge) | 1710 × 1018 |

Three logged or assumed categories are **not in these reads** and could not be scored:
Claude Desktop's sidebar, New chat, and settings buttons (the window read has no
sidebar); Obsidian's file list (collapsed); Slack's send button (disabled while the
composer is empty, so the filter excludes it). Safari's tabs are absent too, since a
window with one tab shows no tab bar.

## Counts

"Targets" is what the clickable filter admits; tiers are the first cut's.

| Window | Elements read | Targets | Tier 1 primary | Tier 2 link or button | Tier 3 row or cell | Tier 4 other |
|---|---|---|---|---|---|---|
| Safari | 1276 | 91 | 14 | 73 | 0 | 4 |
| Chrome | 1799 | 116 | 39 | 77 | 0 | 0 |
| Slack | 391 | 104 | 37 | 19 | 11 | 37 |
| Claude Desktop | 246 | 32 | 1 | 20 | 0 | 11 |
| Finder | 344 | 186 | 39 | 7 | 133 | 7 |
| System Settings | 167 | 68 | 25 | 19 | 23 | 1 |
| VS Code | 711 | 112 | 26 | 14 | 0 | 72 |
| Obsidian | 358 | 64 | 3 | 7 | 0 | 54 |

Every window holds more targets than the 26 hint characters: 32 to 186. Singles can
only ever go to a chosen few, so which few — the tier rule — matters more than how many.

Most elements are not targets: Safari drops 976 as not clickable and 208 as outside the
window (the scrolled-away page, which WebKit places truthfully); Chrome drops 176 as too
small (the page clipped to slivers). The target counts are also inflated by duplicates:
156 of Finder's 186 targets are 44 rows — each list-view file is its row, five cells,
and a name field (18 files, 104 targets), each sidebar location its row and a cell
(26 locations, 52 targets). Slack's sidebar rows each carry a pressable group of the
same size, and every Electron window (Slack, Claude Desktop, VS Code, Obsidian) exposes
two to four pressable groups covering most of the window. None of these duplicates
reaches the singles under either rule below, but they spend two-character labels.

## Hit rate

Share of each category's items ranked within N, first cut → the rule recommended below,
now applied. The "after" numbers come from ranking the same reads again: a scratch
re-ranking first reproduced every recorded first-cut rank exactly, and once the rule
landed, the shipped `TargetRanker` run over the recorded elements gave the same order
and tiers as that re-ranking in all eight windows.

| Window | Category | Items | N = 12 | N = 16 | N = 20 |
|---|---|---|---|---|---|
| Safari | article links (logged) | 10 | 0 → 9 | 0 → 9 | 0 → 9 |
| Chrome | tabs (logged) | 10 | 10 → 10 | 10 → 10 | 10 → 10 |
| Chrome | article links (logged) | 9 | 0 → 1 | 0 → 5 | 0 → 9 |
| VS Code | explorer files and folders (logged) | 37 | 0 → 7 | 0 → 10 | 0 → 13 |
| Slack | sidebar rows: views, section headers, two conversations (assumed) | 11 | 0 → 5 | 0 → 8 | 0 → 10 |
| Slack | thread reply buttons (assumed) | 3 | 0 → 0 | 0 → 0 | 0 → 0 |
| Finder | sidebar locations (assumed) | 26 | 2 → 10 | 5 → 13 | 9 → 17 |
| Finder | list-view files and folders (assumed) | 18 | 0 → 0 | 0 → 0 | 0 → 0 |
| System Settings | sidebar panes (assumed) | 23 | 10 → 11 | 14 → 15 | 18 → 19 |
| System Settings | the pane's controls (assumed) | 14 | 0 → 0 | 0 → 0 | 0 → 0 |

| Summary | N = 12 | N = 16 | N = 20 |
|---|---|---|---|
| Logged categories, mean of shares | 25% → 55% | 25% → 68% | 25% → 81% |
| Assumed categories, mean of shares | 9% → 22% | 13% → 31% | 19% → 40% |
| All items pooled (161) | 14% → 33% | 18% → 43% | 23% → 54% |

The only logged category the first cut serves is Chrome's tabs. Every article link,
in both browsers, ranks 50 or below; every VS Code explorer row ranks 54 or below.

Several categories are larger than any N — VS Code shows 37 explorer rows, Finder 44
wanted rows — so a share well under 100% can still mean the singles are full of wanted
items. What the first 16 singles go to, per window:

| Window | First cut: the 16 singles | Recommended: the 16 singles |
|---|---|---|
| Safari | 11 browser toolbar buttons, the address field, the site's 2 search fields, 2 window buttons | 9 article links, 6 other main-content links (one of them an ad), the address field |
| Chrome | 10 tabs, 5 toolbar buttons, the address field | 10 tabs, 5 article links, the address field |
| VS Code | 11 toolbar buttons, 5 activity-bar tabs | 10 explorer rows, 6 activity-bar and panel tabs |
| Slack | 16 toolbar buttons (the top bar, the sidebar's header, the channel header) | 8 sidebar rows, 7 workspace-rail and channel tabs, the sidebar's search field |
| Finder | 9 toolbar buttons, the search field, 5 sidebar locations, a sidebar heading | 13 sidebar locations, 2 sidebar headings, the search field |
| System Settings | the back button, the search field, 14 sidebar panes | the search field, 15 sidebar panes |

## Misses, and what puts them there

**Browser article links (first cut: rank 50–91).** A link is tier 2, and tier 1 is the
browser's own toolbar: a button in an `AXToolbar` is primary, so Safari's 11 toolbar
buttons and Chrome's 26 (15 of them the bookmarks bar) take the first tier together with
the address field and — being text fields — the site's search boxes. Within tier 2,
reading order then serves the three window buttons, the site's header links, and the
site's navigation bar (22 links in both browsers, all inside the page's
`AXLandmarkBanner` / `AXLandmarkNavigation`) before the first headline. The pages mark
their regions: every headline sits under `AXLandmarkMain`, the header and nav bar under
`AXLandmarkBanner` / `AXLandmarkNavigation`, and most ads inside a second, nested
`AXWebArea` (an iframe) — every product-ad tile on Chrome's page does, while two
ad links in Safari's read do not.

**VS Code explorer rows (rank 54–104).** Two rules miss them. The rows are not
targets at all: each `AXRow` sits in an `AXGroup` inside the `AXOutline`, not directly
in it, and has no `AXPress`; the pressable element is a group two levels inside the
row, which lands in tier 4. And the outline starts 70 pt from the window's leading edge,
behind the activity bar, so it fails the sidebar test (at most 16 pt in) regardless.

**Slack sidebar rows (rank 57–67).** The rows are targets, but the outline starts 88 pt
in, behind the workspace rail, so they fall to tier 3 as content rows. The singles go to
the 16 toolbar buttons of the top bar, the sidebar's header, and the channel header.

**Finder sidebar (5 of 26 at N = 16).** The rows pass the sidebar test, but the 9
toolbar buttons and the search field share tier 1 and come first in reading order.

**Not fixed by the recommendation, and why.** Finder's list-view rows (rank 48 and
below) and System Settings' pane controls (rank 30 and below) sit behind a sidebar
that alone holds 29 and 23 primaries; Slack's reply buttons (rank 48 and below) behind
23. Ranking a window's content above its sidebar is a choice between two assumed
categories the owner did not rank, so this note does not make it. The last Safari
article link (rank 31 after the change) is a larger image link lower on the page; the
29 main-content links above it include trending-topic links, "more" links, and two ad
links that are not in an iframe — an ad the page renders itself is indistinguishable
from content by role and structure.

## Recommendation, applied

**Change the tier rule; keep N = 16.** The owner accepted this, including edit 1's
cost, and it is applied in the same pull request (`docs/decisions.md` › "The tier rule
after #37's measurement; N stays 16").

Four edits to `FirstCutTiers` (`Packages/HintjumpKit/Sources/HintjumpCore/FirstCutTiers.swift`),
nothing else — the filter, the order within a tier, `TargetTier`, and `RankedTarget` stay:

1. **A toolbar button is no longer primary.** `isToolbarOrDialogButton` keeps `AXSheet`
   and the dialog window subroles and drops `AXToolbar`; toolbar buttons fall to tier 2
   with every other button. This is the change the rest depend on: without it, every
   other edit below leaves the singles to the toolbar (pooled 22% at N = 16).
2. **A link in a page's main content is primary**: `AXLink` with an ancestor whose
   subrole is `AXLandmarkMain` and exactly one `AXWebArea` among its ancestors (a second
   one is an iframe, where ads live). On a page without a main landmark the links stay
   tier 2, behind the tabs and, in reading order, after the browser's toolbar.
3. **Nothing inside a page's `AXLandmarkBanner` or `AXLandmarkNavigation` is primary** —
   the site's header, navigation bar, and search box. Its links stay tier 2 and its
   text fields fall to tier 3, like a text field in a row.
4. **The sidebar test is structural rather than an edge distance.** A row is a sidebar
   row when the nearest `AXOutline` / `AXTable` above it lies wholly in the window's
   leading third (`maxX - window.minX <= window.width / 3`), which admits an outline
   behind an icon rail (Slack 88 pt, VS Code 70 pt) and still rejects a full-width
   list. And a pressable element within two levels of an `AXRow` that is not itself a
   target (no `AXPress`, not directly in an outline or table — VS Code's shape) takes
   that row's place; when the row is a target, its children stay where they are, so a
   row is never labeled twice.

What edit 1 costs: every toolbar button loses its claim on a single — the browsers'
back and reload buttons, Finder's view switcher, Slack's top bar and its composer
buttons (the send button among them, which ranks past 30 under either rule). No logged
category contains a toolbar button, which is why the data favors the change; if the
owner clicks one of these often, this is the edit to weigh.

Measured on these reads, the four together take the logged categories from 25% to 68%
at N = 16 (mean of shares) and every item pooled from 18% to 43%. Edit 3 alone is worth
two Chrome article links at N = 16; edits 1, 2, and 4 each carry a category.

Considered and left out: demoting the window's close, minimize, and zoom buttons, and
demoting links inside an iframe to tier 4. Both are what the owner would want, but
neither changes any number above — those elements are tier 2 behind a full tier 1 in
every scored window — so the data does not ask for them. They would matter in a window
with few primaries (Claude Desktop's and Obsidian's reads, where the window buttons take
singles 7–9 and 4–6), where no wanted category was scored. The window buttons were
later demoted anyway, by #87 (`docs/decisions.md` › "The tier rule after #37's
measurement; N stays 16").

**N stays 16.** Under the recommended rule every added single buys about three points
of the logged share (68% at 16, 74% at 18, 81% at 20) with no knee, and each one costs
26 two-character labels: the supply is 276 at N = 16, 226 at 18, and 176 at 20 —
below Finder's 186 targets here, so N = 20 would leave some of a Finder list view with no
hint, one of the two decisive failures in `docs/decisions.md` › Speed budget. The rule
change is worth +41 items pooled at N = 16; raising N from 16 to 20 under the first cut
is worth +8.

**Tests that pin it**, in `Packages/HintjumpKit/Tests/HintjumpCoreTests/`:

- `TargetRankerTests+Tiers.swift` ("tiers"): "a button nested in a toolbar", "a menu
  button in a toolbar", and "a segment in a toolbar" are now plain buttons
  (`.linkOrButton`); a button in a sheet or a dialog stays `.primary`. The outline case
  away from the leading edge became "a row in a narrow outline past the leading third".
- `TargetRankerTests+Regions.swift` ("tiers by region"), new: an outline behind an icon
  rail, one ending exactly at the leading third (`.primary`) and one ending a point past
  it (`.rowOrCell`); a pressable nested row, and a pressable group one and two levels
  inside a non-target row (`.primary`), three levels inside (`.other`), inside a target
  row or a pressable row (keeps its tier), and inside a content row or a row with no
  outline above it (keeps its tier); a link under the main landmark (`.primary`), under
  it but in an iframe, with no web area, or on a page with no landmarks
  (`.linkOrButton`); a button under the main landmark (`.linkOrButton`); anything under
  a banner or navigation landmark, including inside the main landmark, never primary.
- `TargetRankerTests+Order.swift`: a browser-shaped window ranks its tabs, then the main
  landmark's links, ahead of its toolbar, the site's navigation, and an iframe's link;
  an editor-shaped window ranks an explorer row, pressed through a group two levels
  inside it, ahead of the title bar's toolbar button.

`LabelAssignerTests` needs no change while N stays 16.

## Follow-ups this note does not settle

- A re-read of Claude Desktop's main window (with its sidebar) and of Obsidian with its
  file list open, to score the logged categories these reads could not; edit 4 is
  expected to cover Claude's sidebar but is unverified there. Re-read for Claude
  Desktop in #110: edit 4 does not cover it (its sidebar is a complementary landmark of
  buttons, with no outline or rows), so a rule of its own now does (`docs/decisions.md`
  › "The tier rule after #37's measurement; N stays 16" › Amended (#110)).
- Whether a window's content rows (Finder's files, a Settings pane's controls) should
  outrank its sidebar — an owner call, since both categories were assumed.
- Duplicate targets (a row and its cells, a row and its same-size inner group,
  window-sized pressable groups) are a filter question, not a tier one: collapsing them
  would take Finder from 186 targets to about 70 and free two-character labels.
  Settled by #86: the ranker now collapses all three (`docs/decisions.md` › "The tier
  rule after #37's measurement; N stays 16" › Amended (#86)).
