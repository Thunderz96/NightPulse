# NightPulse — WoW Midnight Addon

A Mythic+ and raid companion for ranged DPS. Tracks M+ affix timers, boss ability warnings, and logs your progression history.

## Features

- **Callout engine** — pre-timed boss ability warnings using Blizzard's encounter framework (Midnight 12.0 compliant, no CLEU)
- **Affix tracker** — displays this week's affixes on login with ranged DPS tips; countdown warnings for timed affixes (Incorporeal, Afflicted)
- **Progression log** — records every M+ key and raid boss attempt to disk; view history with `/np log`
- **Minimap button** — draggable, click to toggle the config panel

## Usage

```
/np              Open config panel
/np log          Show last 10 recorded runs
/np log 20       Show last 20 runs
/np best         Show best timed key
/np affixes      Print this week's affixes
```

## Installation

Install via CurseForge, or drop the `NightPulse` folder into:
```
World of Warcraft/_retail_/Interface/AddOns/
```

## Compatibility

- **WoW Midnight 12.0.1** — fully compatible with Blizzard's Midnight API restrictions
- Does **not** use `COMBAT_LOG_EVENT_UNFILTERED` inside instances

## Changelog

See [CHANGELOG.md](CHANGELOG.md)

## License

MIT — see [LICENSE](LICENSE)
