# Verification 3: can the topmost open menu, popover, sheet, or panel be identified?

Answers #9. Runs made on 2026-09-22 on macOS 26.5.2 (25F84), Apple silicon, with two
displays attached (the primary is 2560 × 1440; the second sits to its right). The
developer opened each case by hand while the probe watched; the probe itself never
clicked, typed, or activated anything.

## Method

- **The watch.** `just probe front --watch <seconds>` (`Tools/hintjump-probe`, at
  4cb5386) with `--app` omitted, so it followed the frontmost application. Every
  500 ms it read the signals below without walking a tree (p50 10–17 ms per sample
  across seven sessions, about 2,400 samples in all) and printed a full snapshot whenever their
  one-line signature changed: the frontmost pid and the system-wide
  `AXFocusedApplication` pid, `AXFocusedWindow` and its role and subrole, every
  `AXWindows` entry, menu bar and status items reporting `AXSelected` and the `AXMenu`
  under them, `AXMenu` children of the application element, every on-screen
  `CGWindowListCopyWindowInfo` window above the normal layer (layer, bounds, owner pid
  and name), and each window, sheet, popover, drawer, or menu in a `batchedPruned`
  application read with its clickable count. That count is `TargetRanker`'s targets
  in the subtree rooted at the container, which is what the app would label there.
  Any other application owning such a window outside the menu bar strip was read the
  same way under its own pid. A full snapshot took 97–567 ms (p50 208 ms over 207
  snapshots). That includes every other process read, so it is a probe cost, not a
  trigger cost.
- **The hit-test sampler.** A throwaway script, run alongside the watch for the
  context-menu, sheet, panel, and system-panel cases, kept outside the repository.
  Every 500 ms it took each on-screen window at layers 3–999 (not the window server's,
  not full-screen, not 40 pt tall or less), asked the system-wide element for the
  element at a point 20 pt below the window's top edge, and printed that element's
  role chain up to the application. `front` then gained the same hit test for the
  frontmost application's pop-up-menu-level windows (the `popup` lines, dfcc737), and
  one more watch with that version, 2026-09-22 20:19, read a Finder context menu
  through it. That run is where the context menu's clickable count comes from.
- **The hotkey.** With the Debug app running, the developer pressed ⌃⇧Space in some of
  the cases; whether it was delivered is read from the app's unified log
  (`trigger pressed: click_in_window`).

Clickable counts are ranges across repeated openings. Pids are "frontmost" when the
container belongs to the application `NSWorkspace` reports frontmost, and "other"
otherwise.

## Results

| Case | How it was produced | The signal that identifies it | Container (role/subrole) | Clickable | Pid | Hotkey delivered? |
|---|---|---|---|---|---|---|
| Nothing special | a plain Finder window, list view | no pop-up-menu-level window; `AXFocusedWindow` is the window | `AXWindow/AXStandardWindow` | 183–187 | frontmost | yes (tried on two Electron apps' plain windows; hints shown) |
| App menu open | Finder › File (also Go and Window, and TextEdit › File) | the `AXMenuBarItem` reports `AXSelected`, and the `AXMenu` under it has a real frame; a same-pid window at layer 101 (`kCGPopUpMenuWindowLevel`) with the menu's bounds; `AXFocusedWindow` is usually empty and `AXFocusedUIElement` is the application | `AXMenu` under the `AXMenuBarItem` | Finder File 8–10 with nothing selected, 27 with an item selected (42 elements either way); Go 18, Window 10; TextEdit File 15 | frontmost | **no** (two attempts, no `trigger pressed` line) |
| Context menu open | right-click a file in a Finder list | only the same-pid layer-101 window. `AXFocusedWindow` is empty, `AXFocusedUIElement` is the application, the application element has no `AXMenu` child, nothing on the menu bar is selected, and the right-clicked element does not list the menu in `AXChildren` (the window read's element count did not change). Hit-testing inside the window answers `AXMenuItem` < `AXMenu` < `AXOutline` < `AXScrollArea` < `AXSplitGroup` < `AXSplitGroup` < `AXWindow` < `AXApplication`: the menu's parent is the element that was right-clicked. The probe's own `popup` line found the same thing (`chain=AXMenuItem<AXMenu`, `parent=AXOutline`, the menu owned by Finder's pid, its frame equal to the window's bounds) | `AXMenu` (31 children) | 27 (47 elements; the probe's `popup` line, one opening, menu read in 34 ms) | frontmost | **yes**: it fired and the session logged `trigger ignored: no focused window`; the menu stayed open |
| Popover | the Tags button in Finder's toolbar | an `AXPopover` inside the focused window's subtree (depth 9); `AXFocusedWindow` unchanged, focus inside the popover. No window of its own | `AXPopover` | 17 (37 elements) | frontmost | not tried |
| Sheet | ⌘S in an unsaved TextEdit document | `AXFocusedWindow`'s role is `AXSheet` (no subrole, `AXMain` false); in the application tree it sits at depth 2 under the document window | `AXSheet` | 99 (207 elements) | frontmost | not tried |
| Alert | ⌘W on an unsaved TextEdit document | the same as the sheet: `AXFocusedWindow`'s role is `AXSheet`. On this macOS the save-changes alert is a sheet, not an `AXDialog` window | `AXSheet` | 8 (16 elements) | frontmost | not tried |
| Floating panel | ⌘T (Fonts) in TextEdit | an extra `AXWindows` entry, `AXWindow/AXFloatingWindow` with `AXMain` false, and a same-pid window at layer 3; `AXFocusedWindow` stays the document window | `AXWindow/AXFloatingWindow` | 43 (80 elements) | frontmost | not tried |
| Status-item panel from another process | click Wi-Fi in the menu bar | the frontmost application does not change; the system-wide `AXFocusedApplication` becomes Control Center's pid, and Control Center owns a window at layer 23 (458 × 1387 at the right edge) whose application's `AXFocusedWindow` is `AXWindow/AXSystemDialog`. No status item in Control Center's `AXExtrasMenuBar` reports `AXSelected`; the hit test at that window's top answered nothing | `AXWindow/AXSystemDialog` | 5 (11 elements) | other | not tried |
| Notification Center | click the clock | the system-wide `AXFocusedApplication` becomes Notification Center's pid; its full-screen layer-21 window's application answers `AXFocusedWindow` `AXWindow/AXSystemDialog` | `AXWindow/AXSystemDialog` | 11 (57 elements) | other | not tried |
| Spotlight | ⌘Space | the system-wide `AXFocusedApplication` becomes Spotlight's pid; Spotlight owns two layer-23 windows (720 × 136 and, inside it, 640 × 56; both grow when results appear), and its `AXFocusedWindow` is `AXWindow/AXSystemDialog` | `AXWindow/AXSystemDialog` | 2 (4 elements; 57 with results showing, still 2) | other | not tried |

Rows seen in the same sessions that the issue did not list:

| Case | Signal | Container | Clickable | Pid |
|---|---|---|---|---|
| A third-party launcher panel (Raycast) | as Spotlight: the system-wide `AXFocusedApplication` is the launcher's pid, which owns a layer-8 window whose `AXFocusedWindow` is `AXWindow/AXSystemDialog` | `AXWindow/AXSystemDialog` (web content inside) | 10 (119 elements) | other |
| A second Finder popover | an `AXPopover` at depth 9 of the focused window, `AXFocusedUIElement` an `AXGroup/AXHostingView`, and — unlike the Tags popover — a same-pid layer-101 window with exactly the popover's bounds | `AXPopover` | 13 (18 elements) | frontmost |
| A submenu of a Finder context menu | a second same-pid layer-101 window, listed before its parent menu (the window server lists front to back). Hit-testing it answers `AXMenuItem` < `AXMenu` (12) < `AXMenuItem` < `AXMenu` (43) < `AXMenuBarItem` < `AXMenuBar`: the submenu is shared with the File menu and its ancestors run through the menu bar, not through the context menu | `AXMenu` | not counted | frontmost |
| A menu inside Notification Center | while Notification Center had focus, a Notification Center window at layer 101 with an `AXMenu` inside Notification Center's own tree (depth 3) | `AXMenu` | 4 (5 elements) | other |
| Finder's desktop clicked | `AXFocusedWindow` is the desktop's `AXScrollArea`, not a window; `AXWindows` lists that scroll area at all times | `AXScrollArea` | not counted | frontmost |

## What the numbers say

- **Every case the issue lists can be told apart**, and each by a different signal. No
  single attribute answers "what is on top": the rule below has to ask several in turn.
- **A context menu is invisible to the tree.** It is not a child of the application,
  not selected on a bar, and not among the clicked element's children. It shows up
  only as a pop-up-menu-level window, and a hit test inside that window is the only
  way found to reach the `AXMenu` element. While it is open `AXFocusedWindow` is
  empty, so today's collector ignores the trigger ("no focused window").
- **A panel another process draws is found through the system-wide focused
  application**, not through the window list alone. Notification Center's
  full-screen layer-21 `AXSystemDialog` window is on screen even when Notification
  Center is closed (8–12 elements, 1–3 clickable), and it appeared at intervals during
  a ten-minute idle watch. "Some process owns a window above the normal layer" is
  therefore a false positive on its own. The focused-application pid switches to
  Control Center, Notification Center, Spotlight, or the launcher exactly while their
  panel is open, and back when it closes.
- **The app-menu clickable spread is the menu's enabled items.** `TargetRanker` drops a
  disabled item. How many of Finder's File items are enabled depends on the selection:
  8–10 with nothing selected, 27 with a file selected, when the menu also grows wider.
  The element count (42) never changed.
- **Sheets and alerts need nothing new.** `AXFocusedWindow` already answers the sheet,
  so a `.focusedWindow` read starts from it.
- **A popover needs no new root either**: it is inside the focused window's subtree.
  But one Finder popover also had a layer-101 window of its own, so a layer-101
  window is not always a menu. The hit test tells them apart: no `AXMenu` among the
  hit element's ancestors.
- **Spotlight's results are not counted as targets.** With results showing, 57
  elements came back and `TargetRanker` admitted 2. Its result rows do not pass the
  clickable filter. That is #48's to look at, not this verification's.

## Noise the rule has to ignore

- Small `AXWindow/AXDialog` windows, about 84 × 77 pt, at layer 3, owned by the
  frontmost application (seen in two Electron apps, TextEdit, and a terminal). They
  appear in `AXWindows` for a second at a time, 2 elements and 1 clickable each. One
  terminal also listed `AXDialog` windows of 34 × 30 and 53 × 48 pt and an
  `AXHelpTag` in `AXWindows`. None is ever `AXFocusedWindow`.
- Notification Center's full-screen layer-21 window while it is closed (above).
- A full-screen layer-20 Dock window that comes and goes without any change of focus.
  Also a full-screen layer-24 screenshot-service window, and a third-party app's layer-3
  window, both on screen throughout.
- Hintjump's own overlay: a full-screen layer-101 `AXSystemDialog` window, and while it
  is shown the system-wide `AXFocusedApplication` is Hintjump's own pid.
- A closing menu's layer-101 window stays on screen for up to a second after the menu
  has gone. A hit test inside it then falls through to the window beneath (`AXRow`,
  `AXCell`), and the closing menu itself can report an odd non-empty frame
  (`0,917,239,523`, `0,1440,10,10`).
- A closing Spotlight: its results window was still on screen after the focused
  application had already returned to the frontmost app.
- Spotlight's outer 720 × 136 window is a transparent margin round the 640 × 56 field.
  A hit test near its top edge answered the window beneath it, owned by another process.
- The system-wide `AXFocusedApplication` failed with `kAXErrorCannotComplete` (-25204)
  on the first sample while an Electron app was frontmost, and answered from the next
  sample on.
- The second display's status items (at y = 328) are not inside the primary screen's
  menu bar strip, so they are not recognized as status items. Multi-monitor support is
  a product non-goal; this is recorded, not handled.

## The targeting rule

What a frontmost-window trigger reads, as ordered checks. The first that matches wins.

1. **Another process's panel.** The system-wide `AXFocusedApplication` pid is neither
   the frontmost application's nor Hintjump's own, and that process owns an on-screen
   window above the normal layer. The window is not wholly inside the menu bar strip
   and is taller than 40 pt. Target that process's `AXFocusedWindow`. This covers
   Control Center's panels, Notification Center, Spotlight, and third-party launchers
   (`AXSystemDialog` in every case seen). The focused-application condition is what
   rules out Notification Center's closed window and a Spotlight window that is still
   closing.
2. **A context menu.** Otherwise, if the frontmost application owns an on-screen
   window at `kCGPopUpMenuWindowLevel`, hit-test the frontmost such window: the first
   the window server lists, which is a submenu when one is open. Test 20 pt below its
   top edge, walk up from the hit element to the nearest `AXMenu`, and target that menu
   if it belongs to the frontmost pid. When no `AXMenu` is found (a menu fading out, or
   a popover drawn at that level), go on to check 3. A menu-bar menu would also match
   here, but the trigger is never delivered while one is open.
3. **A sheet.** Otherwise, if `AXFocusedWindow`'s role is `AXSheet` and no popover
   (check 4) is open in it, target it. This is what a `.focusedWindow` read already
   does. It covers save panels and save-changes alerts.
4. **A popover.** Otherwise, if the focused window's subtree — a sheet's included —
   holds an `AXPopover` with a non-empty frame, target the last such popover in
   pre-order. Only one open popover was ever seen at a time in these runs. When there
   are several, the last is the deepest: a popover opened from inside another is its
   descendant, so it comes later and is the one on top. A popover opened from a
   control in a sheet covers the sheet, so it is looked for there too and wins over
   check 3 (#88). A popover without a frame, or with an empty one, is not on screen and
   is skipped, so an outer popover is taken over a frameless inner one.
5. **The focused window.** Otherwise target `AXFocusedWindow`, whatever its subrole
   (`AXStandardWindow`, `AXDialog`, Finder's desktop scroll area).
6. **Nothing.** With no focused window and nothing matched above, the trigger shows
   nothing, as today.

### Cases the rule leaves out, and what the app does then

- **An open menu-bar menu** is identifiable, but it is out of scope. The Carbon hotkey
  is not delivered while a menu-bar menu is tracking, so no check can run. macOS's own
  keyboard navigation works in an open menu (`docs/decisions.md`, 2026-09-22).
- **A floating panel** (`AXFloatingWindow`, such as TextEdit's Fonts panel) is
  identifiable in `AXWindows`, but it is not focused and not what the trigger targets.
  Check 5 targets the focused window.
- **A layer-101 window whose hit test finds no menu** falls through to checks 3–5, so
  the focused window (or the popover inside it) is targeted.
- **A menu inside another process's panel** (Notification Center's): check 1 targets
  that process's focused window. Whether that window contains the menu was not
  verified.

### Not verified here, left to #48's check on a real Mac

- Whether the hotkey is delivered while Control Center, Notification Center, or
  Spotlight has focus. Only the plain window, the context menu, and the menu-bar menu
  were pressed.
- Whether showing the overlay, a key panel (#44), closes an open context menu before
  the targets are clicked. The one context-menu press ended in "no focused window", so
  no overlay was shown over a menu.
