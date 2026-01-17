# Weeklies Tracker

A World of Warcraft addon for **Classic Mists of Pandaria (5.5.3)** that tracks world boss kills and valor points across all your characters.

## Features

### World Boss Tracking
- **Track all 6 MoP World Bosses**
  - Sha of Anger (Kun-Lai Summit)
  - Galleon (Valley of the Four Winds)
  - Nalak (Isle of Thunder)
  - Oondasta (Isle of Giants)
  - Celestials (Timeless Isle)
  - Ordos (Timeless Isle)

### Valor Point Tracking (New in v2.0)
- **Weekly valor progress** - Track how much valor each character has earned
- **Color-coded progress** - Green (capped), Yellow (>=50%), Orange (<50%)
- **Current valor display** - See total valor on each character
- **Weekly cap tracking** - Uses 1600 valor cap (or API value if available)

### General Features
- **Tabbed interface** - Switch between Bosses and Valor tabs
- **Multi-character tracking** - Automatically records data when you log into each character
- **Realm grouping** - Characters organized by realm with collapsible sections
- **Weekly reset detection** - Automatically clears kill data and valor progress on weekly reset
- **Character management** - Delete or ban characters from the list
- **Customizable display** - Toggle individual bosses, filter by level, show only unkilled/not capped
- **Class-colored names** - Easy identification of character classes
- **Movable & scalable UI** - Position and size the window to your preference
- **Minimap button** - Quick access to toggle the window (left-click) or settings (right-click)
- **Settings panel** - Tabbed GUI for all options (General, Bosses, Valor, Characters)
- **Titan Panel support** - Full integration with Titan Panel addon

## Installation

### Manual Installation

1. Download the latest release from the [Releases](../../releases) page
2. Extract the `WeekliesTracker` folder
3. Copy it to your WoW addons folder:
   ```
   World of Warcraft/_classic_/Interface/AddOns/WeekliesTracker/
   ```
4. Restart WoW or type `/reload` if already in-game

### Upgrading from World Boss Checklist

If you're upgrading from the previous "World Boss Checklist" addon:

**Important**: Install the new addon BEFORE deleting the old one for automatic migration!

1. **Install the new addon first**: Copy `WeekliesTracker` to your AddOns folder (keep the old `WorldBossChecklist` folder)
2. **Log in once**: This triggers data migration from `WorldBossChecklistDB` to `WeekliesTrackerDB`
3. **Then remove the old folder**: Delete `Interface/AddOns/WorldBossChecklist/`
4. **Legacy commands still work**: `/wbc` and `/worldboss` will continue to function

*Note: If you already deleted the old addon folder before installing the new one, the migration won't work (WoW only loads SavedVariables for installed addons). Your old data still exists in `WTF/.../WorldBossChecklist.lua` but would need manual copying.*

### Folder Structure

After installation, you should have:
```
Interface/AddOns/WeekliesTracker/
├── WeekliesTracker.toc
├── Core.lua
├── Data.lua
├── UI.lua
└── Config.lua
```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `/wt` | Toggle the checklist window |
| `/wt show` | Show the window |
| `/wt hide` | Hide the window |
| `/wt bosses` | Switch to Bosses tab |
| `/wt valor` | Switch to Valor tab |
| `/wt help` | Show all available commands |

Legacy commands (`/wbc`, `/worldboss`) still work for backward compatibility.

### Configuration

| Command | Description |
|---------|-------------|
| `/wt config` | Open settings panel |
| `/wt unkilled` | Toggle "show unkilled only" (Bosses tab) |
| `/wt notcapped` | Toggle "show not capped only" (Valor tab) |
| `/wt level <num>` | Set minimum level filter (0 to disable) |
| `/wt scale <num>` | Set UI scale (0.5 - 2.0) |
| `/wt lock` | Toggle frame lock (prevent moving) |
| `/wt reset` | Reset window position to center |

### Boss Tracking

| Command | Description |
|---------|-------------|
| `/wt bosslist` | List all bosses and their tracking status |
| `/wt boss <name>` | Toggle tracking for a specific boss |

Examples:
```
/wt boss sha       -- Toggle Sha of Anger
/wt boss ordos     -- Toggle Ordos
/wt boss celestials -- Toggle Celestials
```

### Character Management

| Command | Description |
|---------|-------------|
| `/wt banned` | List all banned characters |
| `/wt unban <name-realm>` | Unban a character |
| `/wt clear` | Clear ALL character data (with confirmation) |

You can also **right-click** any character in the list to:
- **Delete** - Remove from list (will be re-added on next login)
- **Ban** - Remove and prevent from being re-added

## How It Works

### World Boss Tracking
The addon uses Blizzard's quest completion API to detect world boss kills. Each world boss has an associated hidden quest that gets flagged as complete when you kill the boss that week.

| Boss | Quest ID |
|------|----------|
| Sha of Anger | 32099 |
| Galleon | 32098 |
| Nalak | 32518 |
| Oondasta | 32519 |
| Celestials | 33117 |
| Ordos | 33118 |

### Valor Point Tracking
The addon uses the currency API (currency ID 396) to track valor points. It records:
- Current total valor
- Valor earned this week
- Weekly cap (1600 by default)

Data updates automatically when you earn valor while logged in.

### Data Storage
Data is stored in `WTF/Account/<account>/SavedVariables/WeekliesTracker.lua` and persists across sessions.

## FAQ

**Q: Why isn't my character showing up?**
A: Make sure you've logged into that character at least once with the addon enabled.

**Q: My old World Boss Checklist data is gone!**
A: The addon should automatically migrate your data on first load. If it didn't, ensure both addons aren't installed simultaneously.

**Q: Can I track characters on different accounts?**
A: No, the addon only tracks characters on the same WoW account due to how SavedVariables work.

**Q: The boss shows as killed but I haven't killed it this week?**
A: This can happen if the weekly reset wasn't detected properly. Try `/reload` or wait for the next login after reset.

**Q: Valor isn't updating in real-time?**
A: The addon listens for the CURRENCY_DISPLAY_UPDATE event. Try opening your currency panel or earning valor to trigger an update.

## Compatibility

- **Game Version**: Classic Mists of Pandaria 5.5.3 (Interface 65302)
- **Dependencies**: None (standalone addon)
- **Optional**: [Titan Panel](https://www.curseforge.com/wow/addons/titan-panel-classic) - If installed, the addon will automatically register as a Titan Panel plugin

## Credits

- Inspired by [Merfin's World Boss Checklist WeakAura](https://wago.io/worldboss_checklist)
- Addon created with assistance from Claude

## License

This addon is provided as-is for personal use. Feel free to modify for your own needs.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.
