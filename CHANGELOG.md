# Changelog

This file is the manual changelog used for CurseForge packaging.
Keep the newest release at the top and match the version heading to `VesperGuild.toc`.

Format:
`## <version> - <YYYY-MM-DD>`

## 1.4.0 - 2026-03-08

### Added
- Added a runtime warning when the live Mythic+ season contains a dungeon missing from the static portal metadata catalog.

### Changed
- Promoted the main VesperGuild windows to `DIALOG` strata so roster and portal panels render above overlapping Blizzard cooldown UI.
- Standardized localization by moving English strings into shared defaults and backfilling missing keys in all shipped locale files.
- Updated the keystone abbreviation table and season comments for Midnight Season 1 Mythic+.
- Standardized this changelog for CurseForge-style manual release notes.

### Fixed
- Fixed missing localized strings across core, roster, portals, configuration, automation, and keystone sync flows.
- Fixed roster and portal windows to raise correctly when reopened.
- Fixed silent omission risk for future seasonal dungeons by surfacing missing portal metadata in chat.
