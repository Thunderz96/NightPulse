# Changelog

All notable changes to NightPulse will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
## [2.1.3] - 2026-03-14

### Fixed
- `CalloutEngine`: Wrapped `(endMs - startMs) / 1000` arithmetic in `pcall` — `endMs` and `startMs` returned by `UnitCastingInfo` are secret numbers in Midnight 12.0 and taint any arithmetic outside a protected call
- `CalloutEngine`: Wrapped `not notInterruptible` in `pcall` — `notInterruptible` is a secret boolean in Midnight 12.0; direct boolean inversion outside `pcall` raised `ADDON_ACTION_BLOCKED` errors

## [2.1.2] - 2026-03-14

- Bumped version to align with release numbering (no code changes)

## [2.1.1] - 2026-03-14

- Bugfix callout engine during Delve

## [2.1.0] - 2026-03-13

### Added
- Minimap button — draggable, persists position between sessions
- `MinimapButton.lua` module wired into Core PLAYER_LOGIN

### Changed
- Bumped TOC to 120001 (Midnight 12.0.1)
- Version string updated to 2.1.0

## [2.0.0] - 2026-03-13

### Changed (Midnight 12.0 Compatibility Rewrite)
- **CalloutEngine**: Removed COMBAT_LOG_EVENT_UNFILTERED (deprecated in 12.0)
- **CalloutEngine**: Now uses ENCOUNTER_START + static ability database + C_Timer warnings
- **CalloutEngine**: Hooks UNIT_SPELLCAST_START on boss1..boss5 via UnitCastingInfo()
- **CalloutEngine**: Hooks BOSS_WARNING_ADDED (Blizzard's blessed mechanic relay event)
- **CalloutEngine**: Open-world nameplate hook preserved for non-instance content
- **MainWindow**: Replaced BasicFrameTemplateWithInset (removed in 12.0) with BackdropTemplate
- **Core**: Fixed UIParent reference in DEFAULTS (was evaluated at parse time, now stored as string)
- **ProgressionLog**: Wrapped C_ChallengeMode.GetCompletionInfo in pcall for API stability

## [1.0.0] - 2026-03-01

### Added
- Initial release
- CalloutEngine with CLEU-based spell detection (pre-Midnight)
- AffixTracker with weekly affix display and countdown timers
- ProgressionLog recording M+ keys and raid boss encounters
- MainWindow config panel with scrollable run history
