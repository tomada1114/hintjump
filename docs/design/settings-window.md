# Settings window

The screen-by-screen spec for Hintjump's Settings window, decided on 2026-09-23
(`docs/decisions.md` › "The settings surface: a sidebar Settings window over the
config file"). It supersedes every earlier description of a "Status window": where
the Design entry of `docs/decisions.md`, or the source material #21 ports into
`docs/design/`, describes a Status window, this file is what holds. The issues under
#99 build the window from it and cite it by line.

Strings in the copy tables are exact. `<…>` marks a value filled in at run time. The
Source column says where a string was settled: an issue number, a source file whose
text the window reuses verbatim, or "spec" for a string first written here.

## Window

- Title: "Hintjump Settings".
- A `NavigationSplitView`: a sidebar about 200 pt wide that cannot be collapsed, and a
  detail pane holding a grouped `Form` (`.formStyle(.grouped)`) titled with the pane's
  name.
- Minimum content size: about 680 × 460 pt.
- The selected pane is remembered for as long as the app runs, not across launches.
  The first open after launch shows Getting Started.
- It opens in front of the app that was frontmost, from the status menu's "Settings…"
  (#103), and by itself on first launch and while Accessibility is missing (#107).

## Sidebar

The panes, in order. A pane appears in the sidebar only once the issue that builds it
has landed, so the sidebar never shows an empty pane.

| # | Pane | SF Symbol | Built by | Tile takes the accent while |
|---|---|---|---|---|
| 1 | Getting Started | `hand.wave` | #103 | Accessibility is not granted |
| 2 | Shortcuts | `keyboard` | #104 | never |
| 3 | Hints | `tag` | #105 | never |
| 4 | Apps | `square.grid.2x2` | #106 | never |
| 5 | General | `gearshape` | #105 | never |
| 6 | Config File | `doc.text` | #103 | the last load failed, or (from #102) the file was removed |
| 7 | About | `info.circle` | #103 | never |

### Icon tiles

The signature detail: System Settings' rounded-square icon tiles, drawn as hint tags.

- Shape: a 20 × 20 pt rounded square with the overlay tag's 4 pt corner radius
  (`Palette.cornerRadius`, `Packages/HintjumpKit/Sources/HintjumpUI/HintOverlayView.swift:30`).
- Glyph: the pane's SF Symbol in white, about 12 pt, centered.
- Fill: `#1C1C1E`, the overlay's near-black ink (`Palette.inkRGB`, `HintOverlayView.swift:17`).
- Attention fill: `#E5470F`, the red-orange accent, only while the pane needs the
  user (the last column above). It keeps the role it had in the overlay: "this is the
  one to act on". It is never a decoration, never the controls' tint, and never a
  selection mark. The overlay dropped it with #113 (it was `HintOverlayView.swift:16`
  before commit `b284996`), so this file now defines the value, and #103 declares it
  as a `HintjumpUI` constant of its own.
- A selected row keeps its tile's fill; the row highlight is the system's own.
- The attention is never carried by color alone: the pane says it in words (Getting
  Started's "Not allowed yet", Config File's error line), and the sidebar row's
  accessibility value is "Needs attention" while the tile has the accent.

## Controls

- System controls in the system accent color. The brand accent is not the app's
  `AccentColor`: `App/Assets.xcassets/AccentColor.colorset` stays without a color
  value, so the global accent `project.yml:48` names resolves to the system's. Using
  the brand accent there would spend it on every toggle and dilute its role.
- The window draws only three things of its own: the sidebar tiles, the key chips,
  and the Hints pane's preview.
- A key chip shows a combination as macOS menus do: modifiers in the order ⌃ ⌥ ⇧ ⌘,
  then the key — a letter in upper case, a digit, `Space`, `Return`, `Tab`, `F1`–`F12`,
  or the punctuation character itself. The default click-in-window trigger reads
  `⌃⇧Space`.

## Copy

### Getting Started

The first-run guide (#103), with #107's "explain first, then ask" and its "Try it"
step.

| Element | String | Source |
|---|---|---|
| Section header | Allow Accessibility | #103 |
| Explanation | Hintjump reads the buttons, links, and menus on screen, and clicks the one whose label you type. macOS allows that only for apps you give Accessibility access. | spec |
| Status, not granted | Not allowed yet | spec |
| Status, granted | Allowed | spec |
| Button, until #107 lands | Open System Settings | #103 |
| Button, from #107 | Allow Accessibility… | #107 |
| Note under the button, from #107 | Then turn on Hintjump in the Accessibility list that opens. | spec |
| Section header | Try it | #103 |
| Line while Accessibility is not granted | Allow Accessibility first, then try the shortcuts here. | spec |
| Click in window | Press `<combination>` now: labels appear on this window | #103 |
| Right click in window | Press `<combination>`: the same labels, and the one you type is right-clicked | spec |
| App menus | Press `<combination>`: labels appear on the app menus in the menu bar | spec |
| Status icons | Press `<combination>`: labels appear on the status icons in the menu bar | spec |
| Section header | Turn it off where a shortcut collides | #103 |
| Explanation | If an app uses one of these shortcuts itself, turn Hintjump off in that app and the app gets the key back. You can also choose "Disable in" from the status menu while that app is in front. | spec |
| Link to the Apps pane, once #106 lands | Choose Apps… | spec |

Each `<combination>` is the trigger's current value drawn as a key chip, not the
default.

### Shortcuts

One row per trigger, in `HintjumpConfig.triggers` order (#104). Layout: the title and
its line on the left, the key chip and "Edit" on the right, "Reset" only when the value
differs from the default.

| Element | String | Source |
|---|---|---|
| Row title | Click in window | #104 |
| Row line | Left-clicks an element of the window in front | spec |
| Row title | Right click in window | #104 |
| Row line | Right-clicks an element of the window in front | spec |
| Row title | App menus | #104 |
| Row line | Opens a menu in the menu bar of the app in front | spec |
| Row title | Status icons | #104 |
| Row line | Clicks an icon on the right of the menu bar | spec |
| Button beside the chip | Edit | spec |
| Recorder, recording | Type a shortcut… | #104 |
| Recorder hint, recording | Esc to cancel | spec |
| Button, value differs from the default | Reset | #104 |
| Rejection, another trigger has it | Already used by `<row title>` | #104 |
| Rejection, no modifier | Add ⌃, ⌥, ⇧, or ⌘ | #104 |
| Rejection, key outside the supported set | This key can't be a shortcut. Use a letter, a digit, Space, Return, Tab, F1–F12, or a punctuation key. | spec |
| Under the row, saved but not registered | macOS or another app already uses this shortcut | #104 |

### Hints

The `[hints] characters` field and its preview (#105).

| Element | String | Source |
|---|---|---|
| Field label | Hint characters | spec |
| Help line | Lower-case letters, each once, most preferred first. | spec |
| Error, not a letter | `` `<c>` is not a hint character — use lower-case ASCII letters `` | `ConfigSchema.swift:103` |
| Error, repeated | `` the hint character `<c>` is repeated `` | `ConfigSchema.swift:109` |
| Error, too few | hints need at least 8 characters, and this has `<n>` | `ConfigSchema.swift:116` |
| Button | Reset to Default | #105 |
| Preview header | Preview | spec |
| Preview caption | The first 30 labels, in the order targets get them | spec |

- The errors are the schema's own reasons, shown verbatim, so the field, the Config
  File pane, and the log say the same thing about the same mistake. Only the first
  failing rule shows.
- The preview draws with the overlay's own tag view and `Palette`
  (`HintOverlayView.swift`), uppercased as the overlay shows labels. Since #113 every
  tag has the same yellow style, so a single and a pair differ only in length; #105's
  "single-character labels use the accent fill" predates #113 and no longer applies.
- While the field is invalid, the preview keeps showing the last valid characters.

### Apps

The list of apps where Hintjump is off (#106).

| Element | String | Source |
|---|---|---|
| List header | Hintjump is off in these apps | #106 |
| Row, installed app | `<app name>`, with `<bundle identifier>` as the secondary line | #106 |
| Row, no installed app | `<bundle identifier>`, with the secondary line below | #106 |
| Secondary line, no installed app | Not installed | #106 |
| Empty state | Hintjump works in every app. Add one where its shortcuts collide with the app's own. | #106 |
| "+" button, accessibility label | Add App | spec |
| "+" menu, one item per running regular app | `<app name>` | #106 |
| "+" menu, last item, after a divider | Choose… | #106 |
| "−" button, accessibility label | Remove App | spec |
| Error, the chosen bundle has no identifier | `<app name>` has no bundle identifier, so Hintjump can't list it. | spec |

Adding an app already in the list does nothing and shows nothing (#106).

### General

Launch at login (#105). This pane is also where #20's update settings will go.

| Element | String | Source |
|---|---|---|
| Toggle | Launch at login | #105 |
| Under the toggle, macOS needs approval | macOS needs your approval in Login Items before Hintjump can open at login. | spec |
| Under the toggle, macOS refused to add it | macOS could not add Hintjump to Login Items. | spec |
| Under the toggle, macOS refused to remove it | macOS could not remove Hintjump from Login Items. | spec |
| Button, with either message | Open Login Items Settings | #105 |

The toggle always shows the real state, not the value that was asked for.

### Config File

The file the window writes to (#103), and what the last load said (#102 for watching).

| Element | String | Source |
|---|---|---|
| Explanation | Every setting in this window is saved to this file, which you can also edit by hand, share, and diff. | spec |
| Explanation, second sentence from #102 | Changes you save in another editor apply at once. | spec |
| Path | ~/.config/hintjump/config.toml (`ConfigStore.path`, the home folder shown as `~`) | `UserConfigFile.swift:34` |
| Buttons | Open · Reveal in Finder · Copy Path | #103 |
| Last load, success | Loaded at `<time>` | #103 |
| Last load, error | Line `<n>`: `<reason>` | `ConfigError.swift:20` |
| Under an error | Hintjump keeps using the last settings that loaded. | spec |
| File removed | The config file was removed | #102 |
| Button, file missing | Create Default File | #103 |
| The file cannot be read | Hintjump couldn't read this file. | spec |

- `<time>` is the user's short time style, e.g. "Loaded at 10:42".
- An error line reads, for example, ``Line 12: unknown key `hotkey_left` ``. The
  `<reason>` texts are the parser's and the schema's (`TOMLParser.swift`,
  `TOMLParser+Values.swift`, `ConfigSchema.swift`, `KeyCombination.swift`), shown
  verbatim and not restated here, so this table cannot drift from them.

### About

| Element | String | Source |
|---|---|---|
| Name | Hintjump | spec |
| Version | Version `<version>` (`<build>`) | spec |
| License | MIT License | `LICENSE` |
| Repository link | github.com/tomada1114/hintjump | spec |
| Privacy line | Hintjump sends no analytics. | `docs/decisions.md` › "No analytics" |
| An available update | set by #20 | #20 |

## Status menu

The status item's menu keeps only the fast actions. Items in order:

| # | Item | Key | Why it is there |
|---|---|---|---|
| 1 | Disable in `<App>` / Enable in `<App>` | — | The one action about the app you just left, first because it is the fastest path for the collision in front of you. Absent when there is no such app with a bundle identifier (`StatusMenuModel.swift:21-26`). |
| — | divider | | |
| 2 | Settings… | ⌘, | Every setting, in the place and under the shortcut a Mac app's settings always have. |
| 3 | Open Config File | — | The file is the source of truth; this is the way in for someone who edits, shares, or diffs it. |
| — | divider | | |
| 4 | Quit Hintjump | ⌘Q | A menu-bar agent has no app menu, so this is the only way to quit. |

- "Reload Config" sits after "Open Config File" until #102 watches the file, and is
  gone after that.
- ⌘, and ⌘Q work while the menu is open.
- Today's order (`App/HintjumpApp.swift:29-51`) is "Open Config File", "Reload Config",
  the per-app item, a divider, "Quit Hintjump"; #103 changes it to the one above.
- A broken file also shows "!" on the status icon (#102), and the Config File tile takes
  the accent, so the menu needs no error row.

## Contrast

WCAG 2.x contrast ratios, from the sRGB relative luminance of each pair. The sidebar
backgrounds were judged, not sampled from a screen: the sidebar is a translucent
material, so its real color moves with the desktop behind it.

- Light sidebar: `#ECECEC` (the light window background).
- Dark sidebar: `#323232` (the dark window background) and `#1E1E1E` (a darker desktop
  showing through).
- Selected row: `#007AFF` (light) and `#0A84FF` (dark), the default system blue.

| Pair | Ratio | Needed | Result |
|---|---|---|---|
| White glyph on `#1C1C1E` | 17.01:1 | 3:1 (non-text) | pass, in every appearance |
| White glyph on `#E5470F` | 4.01:1 | 3:1 (non-text) | pass, in every appearance |
| Attention tile `#E5470F` against a normal tile `#1C1C1E` | 4.25:1 | — | recorded |
| `#1C1C1E` tile on the light sidebar `#ECECEC` | 14.40:1 | — | recorded |
| `#E5470F` tile on the light sidebar `#ECECEC` | 3.39:1 | — | recorded |
| `#1C1C1E` tile on the dark sidebar `#323232` | 1.33:1 | — | recorded |
| `#E5470F` tile on the dark sidebar `#323232` | 3.20:1 | — | recorded |
| `#1C1C1E` tile on the dark sidebar `#1E1E1E` | 1.02:1 | — | recorded |
| `#E5470F` tile on the dark sidebar `#1E1E1E` | 4.16:1 | — | recorded |
| `#1C1C1E` tile on a selected row, `#007AFF` / `#0A84FF` | 4.24:1 / 4.66:1 | — | recorded |
| `#E5470F` tile on a selected row, `#007AFF` / `#0A84FF` | 1.00:1 / 1.10:1 | — | recorded |

- The glyph is what identifies a pane, and it sits on the tile's own fill, which does
  not follow the appearance, so it clears 3:1 at the 20 pt tile size in light and dark
  alike. A ratio does not depend on size; the size only decides which threshold
  applies, and a glyph is non-text.
- In dark appearance a near-black tile's edge all but disappears (1.33:1, 1.02:1), and
  the tile reads as a white glyph. WCAG does not require the edge, since the glyph
  already identifies the pane; the attention tile's edge still clears 3:1 on every
  sidebar background measured.
- On a selected row the attention tile and the highlight have the same luminance
  (1.00:1, 1.10:1), and only their hues separate them. The pane states the problem in
  words and the row carries "Needs attention", so nothing is lost for someone who
  cannot tell the hues apart. #103's rendering tests cover the selected-and-attention
  case.

## References

The patterns that shaped the layout, summarized rather than copied:

- A settings row with the label on the left and a key chip plus "Edit" on the right:
  the Shortcuts rows.
- A list of connected apps, each with its icon, its name, and a way to remove it: the
  Apps pane.
- A permission explained in the context of the feature it enables, before the system
  prompt appears: Getting Started's "Allow Accessibility" section (#107).
- A "needs verification" badge inline in a settings row: the messages under a
  Shortcuts row and under General's toggle, shown in place rather than as an alert.
- macOS System Settings itself: a fixed sidebar of rounded-square icon tiles, one per
  group, with a grouped form beside it.
