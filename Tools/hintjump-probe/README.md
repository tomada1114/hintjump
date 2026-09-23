# hintjump-probe

A command-line probe for the first verifications this repository has to run — Electron
trees, read latency, the topmost container, and target counts — built on the same
`AccessibilityTreeReading` port and `AXUIElementTreeReader` adapter the app will use, so
what it measures is what the app will get. It is a separate SwiftPM package on purpose:
it lives outside `Packages/` because a probe exists to print and `.swiftlint.yml`'s
`no_print_in_sources` rightly bans `print` under `Packages/*/Sources/`, and it is never
linked by the app — `project.yml` does not know it exists. Reading another application's
accessibility tree needs the Accessibility permission, which macOS holds against the
*process*, so run it from a terminal that has been granted Accessibility in System
Settings › Privacy & Security; a terminal without it gets `not trusted` and nothing else.
Findings go under `docs/research/`, one file per verification.

Run it with `just probe <command> …`, or `swift run --package-path Tools/hintjump-probe
hintjump-probe <command> …`:

- `dump` — every element of the tree as one line each, then the count and the read
  duration: `just probe dump --app com.apple.finder --scope focusedWindow --strategy naive`.
  With `--rank` (also accepted by `wake`), each row also carries `HintjumpCore`'s
  `TargetRanker` verdict right after its index — `rank=N tier=T` for a target, or
  `rank=- excluded=<reason>` (`notClickable`, `disabled`, `noFrame`, `tooSmall`,
  `outsideWindow` from the clickable filter; `windowSizedGroup`, `insideTargetRow`,
  `underColumnHeader`, or `sameFrame` for a duplicate the ranker collapsed) — and a last
  line counts the targets per tier:
  `just probe dump --app com.apple.finder --rank`. The root of the read bounds the
  targets, so rank a `focusedWindow` read; an `application` read's root has no frame and
  ranks nothing
- `time` — the same read repeated, reported as p50 and p95:
  `just probe time --app com.apple.finder --strategy batched --runs 10`
- `front` — the application's direct children (its windows, panels, and menu bar) and
  its focused-window root, then a snapshot of what is on top, for the topmost-container
  verification (#9): `AXFocusedWindow` and every `AXWindows` entry with its subrole, the
  menu bar titles and status items that report `AXSelected`, every open `AXMenu`, every
  on-screen window above the normal layer from `CGWindowListCopyWindowInfo` (layer,
  bounds, owner pid and name), and each window, sheet, popover, drawer, or menu in the
  tree with its count of clickable descendants — `TargetRanker`'s targets, rooted at
  that container. Each pop-up-menu-level window (layer 101) the frontmost application
  owns — the only signal a context menu gives — is printed as a `popup` line; the
  frontmost one also carries the menu open in it, read the way the app reads a context
  menu (`AXUIElementTreeReader`'s `.popUpMenu` scope, the same read as
  `dump --scope popup`) with its clickable count. Any other application that owns such
  a window outside the menu bar strip (Control Center's panels, Spotlight, Notification
  Center) is read the same way and listed under its own pid:
  `just probe front --app com.apple.finder`. Without
  `--app` it reads whichever application is frontmost. With `--watch <seconds>` it
  samples every `--interval` milliseconds (500 by default), follows the frontmost
  application from sample to sample, and prints a timestamped snapshot only when a
  one-line signature of those signals changes, so a person can open menus and panels by
  hand while it records: `just probe front --watch 300 > front-watch.log`. It only
  reads — it never clicks, types, or activates anything
- `wake` — set `AXManualAccessibility` on the application, which is what Chromium and
  Electron applications wait for, and dump either way:
  `just probe wake --app com.microsoft.VSCode`
