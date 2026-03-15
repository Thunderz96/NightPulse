# Changelog

All notable changes to NightPulse will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.2.0] - 2026-03-14

- `CalloutEngine`: Full Season 1 Midnight M+ ability database — 9 bosses with live pre-cast timer alerts (Nexus-Point Xenas, Algeth'ar Academy, Pit of Saron, Seat of the Triumvirate, Skyreach)
- Remaining 14 bosses (Magisters' Terrace, Maisara Caverns, Windrunner Spire) included as commented-out entries pending encounter ID discovery in-game

## [2.1.3] - 2026-03-14

- Fix: Wrapped `(endMs - startMs) / 1000` arithmetic in `pcall` — secret number taint from `UnitCastingInfo` in Midnight 12.0
- Fix: Wrapped `not notInterruptible` in `pcall` — secret boolean taint raised `ADDON_ACTION_BLOCKED` errors

## [2.1.2] - 2026-03-14

- Bumped version to align with release numbering (no code changes)

## [2.1.1] - 2026-03-14

- Bugfix callout engine during Delve

## [2.1.0] - 2026-03-13

- Added minimap button — draggable, persists position between sessions
- `MinimapButton.lua` module wired into Core PLAYER_LOGIN
- Bumped TOC to 120001 (Midnight 12.0.1)

## [2.0.0] - 2026-03-13

- Midnight 12.0 rewrite: replaced COMBAT_LOG_EVENT_UNFILTERED with ENCOUNTER_START + static ability database + C_Timer warnings
- `CalloutEngine`: hooks UNIT_SPELLCAST_START on boss1..boss5 via UnitCastingInfo()
- `CalloutEngine`: open-world nameplate hook preserved for non-instance content
- `MainWindow`: replaced BasicFrameTemplateWithInset (removed in 12.0) with BackdropTemplate
- `Core`: fixed UIParent reference in DEFAULTS
- `ProgressionLog`: wrapped C_ChallengeMode.GetCompletionInfo in pcall

## [1.0.0] - 2026-03-01

- Initial release
- CalloutEngine with CLEU-based spell detection (pre-Midnight)
- AffixTracker with weekly affix display and countdown timers
- ProgressionLog recording M+ keys and raid boss encounters
- MainWindow config panel with scrollable run history
