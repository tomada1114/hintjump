# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)
- Configuration file at `~/.config/hintjump/config.toml`, written with its comments the
  first time Hintjump runs and re-read on request (no file watching). It accepts a
  documented TOML subset — `#` comments, `[section]` headers, strings, string arrays,
  and booleans — and every mistake in it is reported as `Line N: <reason>`. Defaults:
  the triggers `ctrl+shift+space` (click in window), `ctrl+alt+shift+space` (right-click
  in window), `ctrl+shift+m` (app menus), and `ctrl+shift+s` (status icons); the hint
  characters `asdfghjklqwertyuiopzxcvbnm`; no disabled apps; and launch at login off.
  Disabling Hintjump in an app rewrites only the `disabled` list, leaving the rest of
  the file — comments included — untouched
- Accessibility tree reading: the `AccessibilityTreeReading` port, its `AXUIElementTreeReader`
  adapter, and the `hintjump-probe` command-line tool (`just probe`) the first verifications use

[Unreleased]: https://github.com/tomada1114/hintjump/commits/main
