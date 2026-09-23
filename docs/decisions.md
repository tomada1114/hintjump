# Decisions

The product decisions behind Hintjump, with the reason for each and the
alternatives that were rejected. Append-only: a later entry supersedes an
earlier one rather than rewriting it. `AGENTS.md` › Product is the summary;
this file holds the reasons. Anything still open is a GitHub issue.

The entries dated 2026-09-21 were made while planning, before this repository
existed; the planning notes themselves stay outside the repository, so this
file is their public record.

## 2026-09-21 Free, open source, and its own design

- Decision: Hintjump is free and open source. Its look, vocabulary, and
  config layout are its own, and the README credits the tools that came
  before it.
- Why: putting hint labels on screen elements and typing them is a genre
  that predates every current tool; adopting the idea is fine, copying a
  product is not.
- Rejected: free but closed source; paid or donation-based.

## 2026-09-21 Four entry points, each its own shortcut, never more

- Decision: four triggers, each a separate global shortcut: (1) left click in
  the frontmost window, (2) right click in the frontmost window, (3) the menu
  bar's app menus, (4) the menu bar's status items. The count stays at four.
- Why: narrowing the target set per entry point is what keeps labels short.
  "Press one fixed shortcut, then type" is the simplest model to hold; a
  choice made after the hints appear costs a keystroke and a judgment every
  time.
- Rejected: {left, right} × {window, whole screen}, because the whole-screen
  set is exactly the too-many-labels state; a fixed shortcut per element;
  switching the action with a modifier key; narrowing by screen region; an
  entry point per element kind (exceeds four).

## 2026-09-21 The actions are left click and right click, nothing else

- Decision: a hint does a left click or a right click. Not in scope:
  scrolling, text search, chained or repeated clicks, modifier clicks
  (⌘-click and the like), drag, hover, copy, Mission Control, the Dock,
  multi-monitor support, link detection inside terminals or editors.
- Why: the first user's daily need is a left click; each extra action is
  surface for the kind of defect this genre is known for.

## 2026-09-21 The frontmost entry point targets whatever is on top; after a click, macOS takes over

- Decision: the frontmost-window triggers target the topmost thing — an open
  menu, popover, or panel if there is one, otherwise the window. Once a menu
  or a status item has been clicked open, macOS's own keyboard handling
  (arrows, type-ahead, Return) takes over; Hintjump does not re-label what
  opened. To click inside an opened panel, press a trigger again.
- Why: re-labeling on open needs chained-click machinery and a termination
  rule nobody can state; the standard keys already work.
- Rejected: automatic re-labeling of an opened menu.
- Open: whether the topmost thing can be identified reliably is a
  verification issue.

## 2026-09-21 Labels are ASCII letters; the user types with an ABC input source

- Decision: hint labels use ASCII letters only. The app assumes an ABC input
  source, reads no key codes, and never switches the input source. If a
  trigger is pressed while an IME is on, hints appear as usual, keys that
  match no hint are swallowed, and Esc closes the overlay. The limitation is
  documented rather than worked around.
- Why: fewer moving parts. Input-source switching and key-code reading are
  where this genre's input bugs come from (layouts, IMEs).
- Rejected: reading key codes (layout handling); forcing the ABC source; a
  "switch to ABC" notice (needs input-source detection code).

## 2026-09-21 Single-character labels go to the likeliest targets first

- Decision: in a window, the elements most likely to be clicked get the
  single-character labels; the rest get two characters. A letter used as a
  single never starts a two-character label, so 16 singles leave 10 × 26 =
  260 two-character labels. The ranking rule and the number of singles are
  settled by measurement, not by guess.
- Why: a wrong guess only costs one more keystroke, and the user learns
  nothing new. This is the product's distinguishing feature together with the
  separate entry points.
- Rejected: narrowing by screen region.

## 2026-09-21 The menu-bar entry points stay

- Decision: keep the app-menus and status-items triggers.
- Why: they are separate entry points, so removing them would not reduce the
  labels in a window, and they are where single characters are guaranteed.

## 2026-09-21 Per-app disable, and a text config file

- Decision: the app can be disabled per application. Configuration is one
  text file holding the triggers, the hint characters, and the disabled apps.
- Why: a text file is easy to share and to diff.

## 2026-09-21 No analytics; no promise of zero network; updates are announced

- Decision: the app sends no analytics. It does not promise zero network
  traffic, because checking for updates is traffic and users should be told
  when an update exists and what changed. No usage counters or statistics.
- Rejected: a zero-network promise (incompatible with update checks); a
  usage counter (withdrawn by the first user).

## 2026-09-21 Quality: avoid the defect classes this genre is known for

- Decision: reliable per-app disable, no analytics, no input-source
  switching, and Homebrew from the first release are commitments, chosen
  because each is a recurring complaint against existing tools.

## 2026-09-21 Speed budget and what would make the app unusable

- Decision: hints must be visible within 300 ms of the trigger keydown;
  500 ms is felt as slow. The two decisive failures are hints appearing late
  and the wanted element getting no hint. Legibility matters but ranks below
  both.

## 2026-09-21 Name, distribution, and foundation

- Decision: the app is called Hintjump. Distribution is Homebrew plus a
  notarized direct download; the Mac App Store is out because the app cannot
  be sandboxed. The foundation is macos-app-template: logic in
  `HintjumpCore`, accessibility reading and click synthesis as
  `HintjumpPlatform` adapters behind Core ports. No LLM anywhere: rules and
  OS APIs cover every need.
- Why: the name was free on GitHub, Homebrew, npm, and the .com/.app/.dev
  domains when checked; 19 other candidates were taken or unsearchable.

## 2026-09-21 Electron support is decided on a real machine

- Decision: whether Chromium-based apps (Slack, Claude Desktop) are in the
  first release's scope is decided by reading their accessibility trees on a
  real machine, as one of the first tasks in this repository.
- Why: desk research cannot separate "the technique exists" from "it works
  in this app".

## 2026-09-21 Design: signpost hints, one accent, system controls everywhere else

- Decision: hints are opaque near-black tags with white text; only
  single-character hints are filled with a single red-orange accent. 4 pt
  corner radius, no speech-bubble tail, a 1 pt light halo to cut the tag out
  of dark backgrounds. The right-click entry point uses an outlined variant
  of the same tags plus a "Right click" chip. A hint straddles its target's
  left edge, vertically centered; typing the first character removes every
  non-matching hint at once and dims the typed character. Nothing animates.
  The overlay palette is fixed regardless of system appearance. Settings are
  a status-item menu plus one Status window (which doubles as the first-run
  permission guide), built from system controls and system colors only. An
  available update shows as a dot on the status icon, a menu row, and the
  Status window's About section.
- Why: the overlay sits over other apps' content, where light and dark
  regions coexist, so a fixed high-contrast palette reads faster than one
  that follows appearance. One accent keeps "is this a single character?"
  answerable at a glance. System controls for the settings surface cost
  nothing and inherit appearance, scaling, and assistive support.
- Rejected: keycap-style tags (pale surfaces sink into light backgrounds);
  translucent system materials (contrast depends on the background); blue,
  green, or neutral-only accents; hints at the top-left corner or centered
  over the target; a persistent help panel; notification banners; a tabbed
  standard Settings window; themes.
- The measured values and the screen-by-screen spec live in `docs/design/`
  once ported (a tracked issue).
- Amended (#113): every tag has one style, whatever its label's length: a yellow
  fill (`#FFD60A`) with near-black (`#1C1C1E`) bold monospaced text and a 1 pt
  near-black outline in place of the white halo. On a light background the outline
  separates the tag; on a dark one the fill does, which answers the keycap
  objection above. The right-click entry point inverts it — a near-black fill,
  yellow text, a yellow outline — and so does its "Right click" chip. Labels are
  shown uppercased (capitals of one height read faster than lowercase letters);
  typing is unchanged, since the session lowercases what is typed. The red-orange
  single-character accent is dropped: a label's length already says whether it is
  a single, and in use on Claude Desktop and Chrome a mix of accented and
  near-black tags read as noise rather than information. Tag sizes are unchanged;
  the proportional system bold was rejected because `WW` is wider than a pair tag.
- Amended (#114): a tag no longer straddles its target's left edge. It is centered
  horizontally on the target and straddles its bottom edge, at the bottom center of
  the target's visible part — its frame intersected with the read's root, the same
  rectangle a click lands in the center of — still clamped inside the screen, so a
  target at the screen's bottom edge gets its tag pushed up onto it, and the menu
  bar's tags hang just below it. On the left edge a tag hid what identifies its
  target (a title's first letters, a favicon, a leading icon), neighbors' tags
  stacked on one another, and a row scrolled half out of view was labeled on its
  hidden part. Tags are placed in rank order; one whose box, with a 1 pt gap around
  it, overlaps a tag already placed tries the target's top center, then bottom
  leading (its left edge on the target's left edge), then bottom trailing (its right
  edge on the target's right edge), each clamped the same way, and keeps the bottom
  center when all of them overlap. The best-ranked tag is drawn on top. The "Right
  click" chip keeps its place and takes no part. Accepted cost: on a wide row, such
  as a full-width sidebar entry, the tag sits mid-row rather than beside its short
  title. The rejection of "hints at the top-left corner or centered over the target"
  above still holds: this is neither.

## 2026-09-22 Planning notes stay outside the repository

- Decision: the pre-implementation planning notes are not copied here. What
  they settled is recorded in this file and in issues, rewritten for a public
  repository.

## 2026-09-22 Apple Developer Program enrollment is deferred

- Decision: enrollment happens later. Everything that needs a real signing
  identity — checking that the Accessibility grant survives rebuilds and
  updates, notarization, the Homebrew cask — waits for it.

## 2026-09-22 The app is a menu-bar agent with the App Sandbox off

- Decision: no Dock tile, no app switcher entry; the status item is the whole
  surface (`LSUIElement`). The App Sandbox entitlement is turned off.
- Why: reading other applications' UI through the Accessibility API and
  posting synthesized clicks are never granted to a sandboxed process
  (`docs/distribution.md` › Sandboxed or not).

## 2026-09-22 Config file: a hand-written TOML subset, one path, one write-back

- Decision: the config file is `~/.config/hintjump/config.toml`, parsed by a
  hand-written reader in `HintjumpCore` that accepts a documented subset of
  TOML: `#` comments, `[section]` headers, `key = "string"`,
  `key = ["a", "b"]` (multi-line allowed), and `key = true|false`. Every
  error names its line (`Line N: <reason>`); an unknown key is an error. The
  app writes the commented default file once when none exists and reloads
  only on request. Any key is written back by replacing only its value (a
  key or section the file lacks is appended), and every other byte —
  comments, spacing, key order — stays as written.
- Why: the Settings window's Config File pane shows line-numbered errors, and
  every write-back has to edit the file without destroying the user's
  comments; a hand-written subset gives both with no dependency, and it lives
  under the coverage floor. A dotfile path is the convention for hand-edited, shareable
  configuration; Application Support is for data the app manages.
- Rejected: a TOML decoding dependency (decode-only, error line numbers not
  guaranteed, a dependency to vet); JSON (no comments, hard to edit by
  hand).

## 2026-09-22 Default triggers and default hint characters

- Decision: defaults are ⌃⇧Space (click in window), ⌃⌥⇧Space (right-click
  in window: the same key with ⌥ added), ⌃⇧M (app menus), ⌃⇧S (status
  icons). The hint character set is the 26 letters in the order
  `asdfghjklqwertyuiopzxcvbnm`, home row first; no digits.
- Why: ⌃⇧ is nearly unused by macOS's own defaults, and it avoids the Space
  combinations launchers, input-source switching, password managers, and
  window managers already claim. The check was made from knowledge of common
  tools, not exhaustively on a machine; the defaults are one config line to
  change if a collision turns up.

## 2026-09-22 Updates: a standard update framework with a static appcast, alongside Homebrew

- Decision: in-app update checks use Sparkle reading a static appcast
  published with the GitHub release, so no server or API is involved, and
  the Homebrew cask is kept in step. Implemented after the first release;
  adding the dependency goes through the dependency checklist and needs
  human approval because it ships a binary target.
- Rejected: Homebrew only with an in-app changelog (no update prompt);
  deciding later (the About section's layout depends on it).

## 2026-09-22 Four small questions closed for the first release

- Decision: hint size is fixed, with no setting. The config file is reloaded
  only on request, with no file watching. Launch at login is a config key,
  `launch_at_login`, default `false`, applied through a `ServiceManagement`
  adapter. The overlay stays visible in screen sharing, with no setting.
- Why: the first release is the minimum; each of these is added when real
  use shows it is missing.

## 2026-09-22 Chromium-based apps are in the first release's scope; no wake by default

- Decision: Slack, Claude Desktop, and other Electron or Chromium apps get hints
  like any native app. The reader does not set `AXManualAccessibility` on every
  read; it sets it once per process only when a read comes back with an
  `AXWebArea` that has no children and no `AXWebArea` among its ancestors, as
  insurance for a Mac with no other Accessibility client. No per-app exceptions.
  The ancestor condition (#84) keeps an iframe out: each iframe is its own nested
  `AXWebArea`, and the pruned read leaves an off-screen or sliver-sized one
  childless, which would otherwise wake Safari or Chrome and cost a second read.
- Why: `docs/research/electron-accessibility.md` — all three apps expose their
  chat areas, composers, sidebars, and buttons with `AXPress` on the first read
  of a freshly launched process, with the attribute unset; setting it succeeds
  and changes nothing observable. The one thing this machine could not prove is
  behaviour with no other client present, which is what the fallback covers.
- Rejected: setting the attribute on every read (unnecessary, and it is written
  to a foreign process); `AXEnhancedUserInterface` (changes window-manager
  behaviour, and was never needed); declaring the chat apps unsupported.
- Supersedes: the open item in "Electron support is decided on a real machine".

## 2026-09-22 The reader's strategy is batchedPruned; the read alone gets 200 ms

- Decision: the accessibility reader walks a tree with `ReadStrategy.batchedPruned`
  — every attribute of an element in one `AXUIElementCopyMultipleAttributeValues`
  call, subtrees outside the visible rectangle skipped, tables and outlines read
  through `AXVisibleRows`. Of the 300 ms trigger-to-hints budget, the read alone
  gets p95 ≤ 200 ms; the remaining 100 ms is for ranking, labels, layout, and one
  frame of drawing. Latency is always measured with the target app frontmost.
- Why: `docs/research/read-latency.md`. Batching halves every read; pruning is what
  turns Finder's 9,408-element list view (10 s batched) into 308 elements in 54 ms.
  Four of the five windows clear 200 ms with `batchedPruned`; Chrome misses at
  243 ms p95 because Chromium clips scrolled-away content to 0–2 pt slivers instead
  of placing it off screen, so the rectangle prune keeps everything, and the
  per-element visible-children query costs a round trip Chromium never answers.
  The frontmost rule is empirical: an occluded app is App-Napped and answers five
  times slower, which is a measurement artefact, not a product case.
- Rejected: `batched` alone (Finder stays at 10 s); `naive` (over budget on every
  browser page); a per-application strategy table (the two Chromium fixes are
  adapter-side translation and need no table).
- Open: none. The Chromium fixes (#27) landed the same day: the visible subsets ride
  in the batched call and a frame clipped to 2 pt or less counts as out of view, which
  takes Chrome to 52 / 110 ms (`docs/research/read-latency.md` › After the Chromium
  fixes).

## 2026-09-22 N = 16 and the first-cut tiers, pending #37's measurement

- Decision: provisional. The label assigner gives single-character labels to
  the first 16 ranked targets (`LabelAssigner.defaultSingleCount`), and the
  ranker keeps its first-cut tiers (`FirstCutTiers`) unchanged. With the
  default 26 characters that leaves 10 prefixes, so 16 + 10 × 26 = 276
  targets can be labeled; each prefix runs through the whole set, in set
  order, before the next prefix starts (`ia`, `is`, … `im`, `oa`, …). Targets
  past the supply are not hinted and are counted so the overlay can log how
  many were dropped. Typing matches by prefix: a single selects at once, a
  prefix narrows to its pairs, Backspace undoes the narrowing, Esc cancels,
  and any other key is ignored without closing the hints.
- Why: the measurement this rule was to be chosen on (`docs/research/target-counts.md`)
  was split out of #10 into #37 and does not exist yet, so the fallback stated
  when the label work was planned applies: keep the first cut and N = 16. No
  hit rate backs either number yet. Prefix-major pair order keeps a narrowing
  small when only a few pairs are in use: 20 targets need only the prefix `i`.
- Open: #37 measures how often the wanted element ranks within the singles
  and revisits both the tier rule and N; changing either is a new entry that
  supersedes this one. Neither change alters `RankedTarget` or the assigner's
  output shape.

## 2026-09-22 Clicks are synthesized mouse events at the element's visible center; the pointer stays there

- Decision: a hint clicks by posting a synthesized mouse press and release —
  `CGEvent` at the HID event tap, left or right button, click state forced to 1 —
  at the element's visible center, through the `ClickPerforming` port and its
  `CGEventClickPerformer` adapter. The pointer is left at the click point. Which
  point is the visible center is Core's decision, not the adapter's.
- Why: a synthesized event is the only mechanism that clicks every element kind
  the same way — text fields, rows, web content — right clicks included, where
  `AXPress` and `AXShowMenu` are each supported only by some roles. The pointer
  stays because moving it back races the target app's own handling of the click.
  Posting needs no grant beyond the Accessibility one the app already asks for;
  without it the OS drops the event silently, so the adapter checks the grant
  first and reports it as its own error.
- Rejected: `AXPress` for left clicks (not every clickable element publishes it —
  `docs/research/electron-accessibility.md` shows many do, not all); warping the
  pointer back after the click.
- Supersedes: nothing; it names the API and the pointer behaviour that "Name,
  distribution, and foundation" left as "click synthesis".

## 2026-09-22 Pressing the same trigger again closes the hints; a different trigger replaces them

- Decision: while hints are shown, a second press of the shortcut that showed
  them closes them without clicking; a press of any other trigger closes them
  and shows that trigger's hints instead. Typed characters are lowercased
  before they are matched, and a selected hint's click is posted on the next
  main-run-loop turn after the overlay is hidden. `HintSession` in
  `HintjumpCore` owns the whole sequence, reaching the overlay through the
  `HintOverlayPresenting` port.
- Why: the shortcut a user just pressed is the most natural way out besides
  Esc, and a different trigger means they changed their mind about the target
  set. Lowercasing lets a trigger's Shift still be held while the label is
  typed. Deferring the click by one turn lets the window server order the
  overlay out before the click lands, so the click reaches the target app and
  not the overlay.
- Rejected: ignoring a trigger while hints are shown (leaves Esc as the only
  way out); re-reading and re-labeling on a repeated press of the same trigger
  (a toggle is what a repeated shortcut means everywhere else).

## 2026-09-22 The overlay is a key, non-activating panel that reads typed characters

- Decision: the hint overlay is a borderless, transparent, click-through
  `NSPanel` with `.nonactivatingPanel`, at the `.popUpMenu` level, covering the
  one screen that holds the target window's center. It becomes the key window
  without Hintjump ever calling `NSApp.activate`, and reads each key-down's
  `charactersIgnoringModifiers` — never its key code — as the typed key: Esc and
  backspace are control keys, any other single character is handed to the
  session. Losing key status (an app switch) closes the hints, and so does any
  mouse press while they are shown, seen through a global mouse-down monitor
  (which needs no permission): a click in the target app, which is already
  active, takes keyboard focus back without the panel ever being told it
  resigned key. The adapter is `PanelHintOverlayPresenter` in `HintjumpPlatform`; the
  view it hosts, `HintOverlayView`, is in `HintjumpUI` and is installed by the
  composition root.
- Why: a key window receives its keystrokes from the window server, so the
  overlay takes the typed label without the Input Monitoring permission a
  global key tap needs, and a non-activating panel is key without making
  Hintjump the active app, so the app being clicked keeps its focus and its menu
  bar — typing after Esc goes where it went before the trigger. Reading
  characters rather than key codes is what "Labels are ASCII letters; the user
  types with an ABC input source" requires.
- Rejected: a `CGEventTap` (costs Input Monitoring); temporary Carbon hotkeys
  for each hint letter (key codes, which the ABC decision rules out, and a
  registration per letter per session); activating Hintjump while hints are
  shown (steals focus from the app being clicked and closes an open menu in it).
- Supersedes: nothing.

## 2026-09-22 A disabled app gets every trigger key back

- Decision: while an app listed in `[apps] disabled` is frontmost, all four
  triggers are unregistered — the two menu-bar triggers included — so their
  key combinations reach that app; they are registered again when an app
  that is not disabled comes forward (Hintjump's own activation changes
  nothing). The status menu's per-app item names the last app
  activated other than Hintjump: `Disable in <App>` adds it to the list,
  `Enable in <App>` removes it, and either takes effect at once.
  `DisabledAppsPolicy` in `HintjumpCore` decides, following app switches
  through the `FrontmostAppObserving` port; `HintSession` also ignores a
  press that lands in a disabled app before the switch is noticed.
- Why: a Carbon hotkey consumes its combination for every app, so a hotkey
  that is swallowed but ignored is not disabled. The usual reason to disable
  Hintjump in an app is a shortcut collision, and that applies to all four
  triggers. Naming the last app other than Hintjump keeps opening Hintjump's
  own menu from making Hintjump the subject.
- Rejected: ignoring presses in a disabled app (the app still never receives
  the key); disabling only the two window triggers.

## 2026-09-22 Status items are found in the on-screen window list

- Decision: the status-items trigger finds its targets with one
  `CGWindowListCopyWindowInfo` call — the on-screen windows at the status-item
  level, read for their layer, bounds, and owner pid only — behind the
  `StatusItemListing` port and its `WindowListStatusItems` adapter.
  `StatusItemTargetCollector` in `HintjumpCore` keeps a window only when it is
  more than 2 pt wide and tall and lies wholly inside one visible part of the
  primary screen's menu bar (the two sides of a camera housing, or the whole bar),
  drops a frame reported twice, and orders the rest left to right, like every
  other reading-order rule in the app. Each is left-clicked at its center.
  Hintjump's own status item is a target like any other, and because this
  collector reads nothing of the frontmost app, `HintSession` runs it even while
  Hintjump itself is frontmost; a disabled app, or no frontmost app with a
  process identifier, still shows nothing.
- Why: one call with no TCC grant finds every process's items — third-party
  apps', Control Center's, and Hintjump's — and none of its fields is the one
  Screen Recording gates (`kCGWindowName`). On the macOS 26 Mac this was built on,
  every status-level window in the list is owned by Control Center, so the owner
  pid can name a host process rather than the item's app; it is carried, never
  decided on.
- Rejected: `AXExtrasMenuBar` of every running process (one Accessibility round
  trip per process, and one hung process stalls the trigger past the 300 ms
  budget). If a real run shows an item the window list misses, that item's
  process's `AXExtrasMenuBar` is added as a second source then, not before.

## 2026-09-22 What "whatever is on top" means: an ordered targeting rule; open menu-bar menus are out of scope

- Decision: a frontmost-window trigger resolves its target with these checks, in
  order, the first match winning (`docs/research/topmost-container.md`, runs of
  2026-09-22):
  1. The system-wide `AXFocusedApplication` is a process other than the frontmost
     application and Hintjump itself, and it owns an on-screen window above the
     normal layer, outside the menu bar strip and taller than 40 pt: that process's
     `AXFocusedWindow` (Control Center's panels, Notification Center, Spotlight,
     third-party launchers).
  2. The frontmost application owns an on-screen window at
     `kCGPopUpMenuWindowLevel`: hit-test the frontmost such window 20 pt below its top
     edge and walk up to the nearest `AXMenu` of the frontmost pid. That is the
     context menu (or the submenu open on it). No menu found: go on.
  3. `AXFocusedWindow` is an `AXSheet` (save panels, save-changes alerts): the sheet.
  4. The focused window's subtree holds an `AXPopover`: the popover.
  5. Otherwise the focused window; with none, nothing, as today.

  Open menu-bar menus are out of scope for the frontmost-window triggers. No event
  tap and no Input Monitoring is added to reach them; macOS's own keyboard
  navigation handles an open menu. Floating panels (`AXFloatingWindow`, such as
  TextEdit's Fonts panel) are not targeted either, because they are not focused.
  Both fall back to the focused window: check 5, or check 3 or 4 when a sheet or
  popover is open. Stating that fallback in the README is #48's job, along with the
  rule's implementation.
- Why: the runs identified every case #9 listed, each by a different signal, so no
  single attribute can answer "what is on top".
  - A context menu is reachable only through its pop-up-menu-level window: the
    application element has no `AXMenu` child, nothing on the bar is selected, the
    right-clicked element does not list it, and `AXFocusedWindow` is empty while it
    is open.
  - A panel another process draws is found through the focused-application pid.
    The window list alone gives a false positive: Notification Center keeps a
    full-screen layer-21 window on screen while it is closed.
  - Sheets and alerts need nothing new, because `AXFocusedWindow` already answers
    the sheet.
  - Menu-bar menus are out of scope because the Carbon hotkey is not delivered while
    one is tracking. Two presses with Finder's File menu open logged no
    `trigger pressed` line. With a context menu open the same hotkey was delivered.
- Rejected: an event tap to receive the trigger during menu-bar menu tracking (it
  costs Input Monitoring, the grant "The overlay is a key, non-activating panel"
  above already declines for the same reason); searching the tree for a context menu (it is not in the tree);
  taking any window above the normal layer as the target (Notification Center's
  closed window, the Dock's, the screenshot service's, and Hintjump's own overlay
  are all there); targeting a floating panel (it is not where the keyboard focus
  is).
- Open: #48 implements the rule. It also checks on a real Mac what these runs did
  not test. First, whether the hotkey is delivered while Control Center,
  Notification Center, or Spotlight has focus. Second, whether showing the overlay,
  a key panel (#44), closes an open context menu. Third, why Spotlight's result
  rows do not pass `TargetRanker`'s clickable filter.
- Amended (#88): check 4 takes the last `AXPopover` with a non-empty frame in the
  read's pre-order, the innermost when one popover is opened from inside another,
  and looks inside a sheet too. A popover open in a sheet is therefore targeted
  (`container=popover`) before check 3 takes the sheet; a sheet with no popover
  is still the sheet. The first popover in tree order, and the sheet taken whole,
  both labeled what the topmost popover hides.

## 2026-09-22 The tier rule after #37's measurement; N stays 16

- Decision: supersedes "N = 16 and the first-cut tiers, pending #37's measurement"
  above. The label assigner keeps N = 16 singles
  (`LabelAssigner.defaultSingleCount`, 276 labels with 26 characters). The ranker's
  tier rule (`FirstCutTiers`, edited in place) changes in five ways; the clickable
  filter, the reading order within a tier, and `RankedTarget` do not.
  - A toolbar's buttons are no longer primary; they rank with every other button.
    A sheet's or a dialog's buttons still are.
  - A link under a web page's `AXLandmarkMain`, with exactly one `AXWebArea` above it,
    is primary. A second web area means an iframe, where ads are embedded.
  - Nothing inside a page's `AXLandmarkBanner` or `AXLandmarkNavigation` is primary:
    the site's header, navigation bar, and search box.
  - A sidebar row is one whose nearest outline or table ends within the window's
    leading third, so a sidebar behind an icon rail counts. A pressable element up to
    two levels inside a row that is not itself a target stands in for that row.
  - A window's own close, minimize, zoom, and full-screen buttons (subroles
    `AXCloseButton`, `AXMinimizeButton`, `AXZoomButton`, `AXFullScreenButton`) rank
    last, in every kind of window, checked before any primary rule; a dialog's other
    buttons stay primary. Added by #87 after the first release's target scope below
    took in Claude Desktop, whose read gave them singles 7–9, and in a dialog they
    would have been primary.
- Why: `docs/research/target-counts.md`. Under the first cut the singles went to the
  toolbar in every window read. No browser article link and no VS Code explorer row
  ranked within 16, and the categories the owner named reached 25% (mean of shares).
  The new rule takes that to 68% at N = 16, and every scored item from 18% to 43%.
  Raising N instead gains about three points per single with no knee, and N = 20
  leaves 176 labels, fewer than the 186 targets a Finder list view held.
- Accepted cost: toolbar buttons now get two-character labels. That includes the
  browsers' back and reload, Finder's view switcher, and Slack's top bar and composer
  buttons, Slack's send button among them. The owner accepted this explicitly: none of
  the categories they named is a toolbar button.
- Rejected: N = 18 or 20 (fewer labels for a smaller gain than the rule change);
  demoting iframe links to the last tier (no measured effect; the window's buttons,
  rejected here at first for the same reason, were demoted by #87); a sibling tier
  type beside the first cut (nothing would call the first cut).
- Open: the note's categories were described by the owner, not logged click by click,
  and three of them were not in the reads (Claude Desktop's sidebar, Obsidian's file
  list, Slack's send button). Whether a window's content rows should outrank its
  sidebar, and collapsing duplicate targets (a row and its cells), are left for later.
- Amended (#85): N = 16 is a ceiling. When 16 singles would leave targets unlabeled,
  the assigner keeps the largest `s ≤ min(16, a)` with `s + (a − s) × a ≥ count`
  for `a` hint characters, down to `s = 0` (`a × a` labels) when even that falls
  short. With 8–16 characters a fixed 16 left no prefix at all; with the default
  26 and at most 276 targets the labels are unchanged.
- Amended (#86): duplicate targets are collapsed after the clickable filter, a filter
  question rather than a tier one; the survivors keep their tiers and their order. A
  target admitted only through `AXPress`, not by its role, that covers at least half
  the read's root and holds another target is dropped (Electron's window-sized groups).
  Then an `AXCell`, or an `AXTextField` inside one, is dropped when its nearest `AXRow`
  is still a target: the row keeps the label, since its center selects the item
  without starting Finder's click-to-rename and a right click there opens that item's
  menu; the row's other controls (disclosure triangle, checkbox, pop-up, button) stay.
  Last, of targets with identical frames only the best-ranked stays. A click lands at
  the survivor's visible center either way, so this decides only where a tag sits.
  Each drop is its own `TargetExclusion`, which the probe's `--rank` prints. Finder's
  186 list-view targets were about 74 without these.
- Amended (#98): after what is inside a target row, an `AXRow` is dropped when its
  visible center lies inside a column-header button of its nearest outline or table —
  an `AXSortButton` under it, or an `AXButton` in a group directly in it — since that
  click presses the header; its cells stay dropped with it.
- Amended (#109): right after the window-sized groups, an element admitted only
  through `AXPress` is dropped when its nearest control — the nearest container
  clickable by role, or any `AXRow` — is an `AXButton` or `AXLink` that is still a
  target. Chromium reports `AXPress` on a button's icon and title group, so each Claude
  Desktop sidebar entry took three labels for one destination; HTML allows no
  interactive content in a button or a link, so a click there lands in the control.
  Controls clickable by role inside it stay, and so does the content of a checkbox,
  pop-up or menu button, or row nested in it; a button that is no target keeps its
  content reachable.
- Amended (#110): an `AXButton`, `AXLink`, or `AXPopUpButton` is primary as a web app
  shell's sidebar entry when its nearest `AXLandmarkComplementary` ancestor ends within
  the window's leading third (the sidebar row test's bound) and the element is at least
  half that landmark's width. It applies only when the nearest `AXWebArea` above the
  landmark is an app shell: its top edge within 1 pt of the window's top and its
  leading and trailing edges within 1 pt of the window's, as in an Electron app. A
  browser page sits below the browser's toolbar, so a website's `<aside>` keeps its
  tier. Claude Desktop's sidebar is such a landmark, with buttons and pop-ups in plain
  groups and no outline or rows, so the sidebar row test did not see it: its sessions
  ranked 20 and later and its settings pop-up 42. With this rule its eleven entries join
  the three existing primaries within the 16 singles; the half-width bound leaves the
  sidebar's icon buttons and each entry's 30 pt "…" pop-up as plain buttons. Accepted
  cost: the window's top bar drops to two-character labels, as the toolbars did above.
  The banner and navigation exclusion and #87's window-button demotion still apply
  first.
- Amended (#115): the clickable filter turns away every `AXSplitter`, even one that
  reports `AXPress`, right after the clickable check. A splitter is only ever dragged,
  and drag is a non-goal, so pressing one is never a destination; Claude Desktop's
  "Resize sidebar" splitter, 18 pt wide and the window's full height, put a label on
  the invisible boundary between the sidebar and the transcript. A role check is the
  narrowest rule: no size threshold changes, so no clickable container is at risk. The
  read that chose it (`just probe dump --app com.anthropic.claudefordesktop --rank`,
  2026-09-23, commit 5b294a5) showed the other tall, invisible containers already gone
  — the column-sized transcript groups dropped as window-sized (#86) and the sidebar's
  content group not clickable — and each sidebar entry down to one label besides its
  "…" pop-up (#109). A link wrapped across two lines, anchored at its paragraph's edge,
  is split into #118.

## 2026-09-22 The first release's target scope

- Decision: the owner's call. The first release is judged against a narrow target
  and supports what is listed here; everything deferred is a sub-issue of the post-v1
  parent issue #80 and carries the `on hold` label. In scope:
  - The primary target: the frontmost window of Safari, Chrome, and Claude Desktop,
    ranked by the tier rule in "The tier rule after #37's measurement; N stays 16"
    above.
  - Sheets and dialogs, which are the focused window (#9).
  - Context menus and popovers (#48). Their real-Mac check is #75, which is not on
    hold.
  - The menu bar's app menus and status items, through their own triggers.
  - Other ordinary app windows — Finder, System Settings, VS Code, Slack, Obsidian —
    read through the same path, best-effort, with no support promise.

  On hold (sub-issues of #80):
  - System panels as targets: Control Center, Notification Center, Spotlight, and
    launchers (#79). Check 1 of the targeting rule in "What 'whatever is on top'
    means" above stays in the code and enabled, but the first release does not
    support it.
  - Spotlight's result rows as targets (#77).
  - Learning per-app click locations to rank frequently clicked elements (#73).

  Unchanged by this entry: open menu-bar menus and floating panels stay out of scope
  and fall back to the focused window, and multiple displays stay a product non-goal.
- Why: the split follows what #9, #37, and #48 found.
  - #9 (`docs/research/topmost-container.md`): a sheet or an alert needs nothing new,
    because `AXFocusedWindow` already answers it. A system panel is found only
    through a separate signal, the focused-application pid, and whether the trigger
    is delivered at all while one has focus was not tested.
  - #37 (`docs/research/target-counts.md`): the tier rule was tuned on the categories
    the owner named for Safari, Chrome, VS Code, and Claude Desktop; the categories
    for Slack, Finder, System Settings, and Obsidian were assumed for the note. The
    owner chose the browsers and Claude Desktop as the target the release is judged
    on, and left every other window best-effort.
  - #48 implemented the whole rule. Its real-Mac check of context menus and popovers,
    including whether the overlay closes an open context menu, is #75; the trigger's
    delivery with a system panel focused is still unverified (#79). Spotlight's
    result rows do not pass `TargetRanker`'s clickable filter (57 elements, 2
    admitted), and nothing yet says why (#77).
  - Click learning (#73) is a new ranking input, not a gap in the rule.

  A narrow target lets the first release be judged on what was measured, rather than
  wait on every surface the rule can reach.
- Open: after the first release ships, each sub-issue of #80 is either taken off
  hold or closed as not planned, and #80 closes.
