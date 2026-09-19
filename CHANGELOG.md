# Changelog

All notable changes to dock-numbers, oldest first.

## 0.1.3

- App icon at the top of README
- Version number in `.dmg`/`.pkg` installer filenames

## 0.1.2

- Fix settings group boxes staying dark in light mode

## 0.1.1

- Fix `.pkg` to always install into `/Applications` (no more upgrading stray same-id copies elsewhere on disk)

## 0.1.0

- Hold Option to badge Dock icons, press a number to switch apps (initial prototype)
- Move sources to `src/`, add README, MIT license, AI disclosure
- Tag-triggered release workflow with install docs
- Dock overlay screenshot in README
- Ship the app: `.app` bundle, DMG installer, settings window, themes
- Open a new Finder window when switching to Finder with none open
- `.pkg` installer that puts the app into `/Applications`
- Code-rendered app icon + menu-bar template (no design tools needed)
- Wire custom icon into the `.app` bundle and menu bar
- Show settings window on reopen (Spotlight / click while running)
- Show/hide menu-bar icon setting
- Retain status item, apply menu-bar visibility live
- Settings laid out as a grid: labels left, controls right
- About section in settings: author + repo link
- Restyle settings macOS-style: icon header, grouped sections
- Portable `~/.config` YAML settings store + configurable badge delay
- Settings: delay slider, disk-backed refresh, layout overflow fixes
- `--no-accessibility` flag for headless UI testing
- Group name + repo link under an About section
- Fix settings launch crash, footer centering, row rhythm
- Unify settings alignment: About leading, even row heights
- Show app name (+ version) as menu-bar menu header
- Menu-bar icon: mini dock with badge dots instead of 1-disc
- Match app icon to menu-bar motif; show version in settings
- Honor `XDG_CONFIG_HOME` for the config file location
