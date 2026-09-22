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
  app writes the commented default file once when none exists, reloads only
  on request, and writes back only the disabled-apps list, leaving every
  other line — comments included — untouched.
- Why: the Status window shows line-numbered errors, and "Disable in <App>"
  has to edit the file without destroying the user's comments; a
  hand-written subset gives both with no dependency, and it lives under the
  coverage floor. A dotfile path is the convention for hand-edited, shareable
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
  `AXWebArea` that has no children, as insurance for a Mac with no other
  Accessibility client. No per-app exceptions.
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
