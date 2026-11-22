# Beam — a lightweight Alfred replacement

**What:** A native macOS launcher. ⌘Space opens a floating search bar; type, arrow keys to pick, Enter to run, Esc to hide.
**Who:** Me, replacing Alfred 5 (which has gotten slow).
**Stack:** Swift + AppKit, SwiftPM, no dependencies. Global hotkey via Carbon `RegisterEventHotKey` (no Accessibility permission needed). Runs as a menu-bar-less background agent (LSUIElement).

## Features (v1)
- Apps: launch anything in /Applications, /System/Applications, ~/Applications (fuzzy match, most-used ranked first)
- Files: matching files from Spotlight appear under apps automatically; Enter opens, ⌘Enter reveals in Finder


## Milestones
1. Hotkey + floating panel + app search
2. File search
3. (dropped: clipboard history)
4. Tests for the ranking/parsing core, Makefile, launch-at-login

## Out of scope
Calculator, web search, system commands, clipboard history, Alfred workflows/plugins, snippets/text expansion, themes, settings UI, iCloud sync.
