# World Boss Checklist

A World of Warcraft addon for **Classic Mists of Pandaria (5.5.3)** that tracks world boss kills across all your characters.

![World Boss Checklist Screenshot](https://i.imgur.com/placeholder.png)

## Features

- **Track all 6 MoP World Bosses**
  - Sha of Anger (Kun-Lai Summit)
  - Galleon (Valley of the Four Winds)
  - Nalak (Isle of Thunder)
  - Oondasta (Isle of Giants)
  - Celestials (Timeless Isle)
  - Ordos (Timeless Isle)

- **Multi-character tracking** - Automatically records data when you log into each character
- **Realm grouping** - Characters organized by realm with collapsible sections
- **Weekly reset detection** - Automatically clears kill data on weekly reset
- **Character management** - Delete or ban characters from the list
- **Customizable display** - Toggle individual bosses, filter by level, show only unkilled
- **Class-colored names** - Easy identification of character classes
- **Movable & scalable UI** - Position and size the window to your preference

## Installation

### Manual Installation

1. Download the latest release from the [Releases](../../releases) page
2. Extract the `WorldBossChecklist` folder
3. Copy it to your WoW addons folder:
   ```
   World of Warcraft/_classic_/Interface/AddOns/WorldBossChecklist/
   ```
4. Restart WoW or type `/reload` if already in-game

### Folder Structure

After installation, you should have:
```
Interface/AddOns/WorldBossChecklist/
├── WorldBossChecklist.toc
├── Core.lua
├── Data.lua
├── UI.lua
└── Config.lua
```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `/wbc` | Toggle the checklist window |
| `/wbc show` | Show the window |
| `/wbc hide` | Hide the window |
| `/wbc help` | Show all available commands |

### Configuration

| Command | Description |
|---------|-------------|
| `/wbc config` | Display current settings |
| `/wbc unkilled` | Toggle "show unkilled only" mode |
| `/wbc level <num>` | Set minimum level filter (0 to disable) |
| `/wbc scale <num>` | Set UI scale (0.5 - 2.0) |
| `/wbc lock` | Toggle frame lock (prevent moving) |
| `/wbc reset` | Reset window position to center |

### Boss Tracking

| Command | Description |
|---------|-------------|
| `/wbc bosses` | List all bosses and their tracking status |
| `/wbc boss <name>` | Toggle tracking for a specific boss |

Examples:
```
/wbc boss sha       -- Toggle Sha of Anger
/wbc boss ordos     -- Toggle Ordos
/wbc boss celestials -- Toggle Celestials
```

### Character Management

| Command | Description |
|---------|-------------|
| `/wbc banned` | List all banned characters |
| `/wbc unban <name-realm>` | Unban a character |
| `/wbc clear` | Clear ALL character data (with confirmation) |

You can also **right-click** any character in the list to:
- **Delete** - Remove from list (will be re-added on next login)
- **Ban** - Remove and prevent from being re-added

## How It Works

The addon uses Blizzard's quest completion API to detect world boss kills. Each world boss has an associated hidden quest that gets flagged as complete when you kill the boss that week.

| Boss | Quest ID |
|------|----------|
| Sha of Anger | 32099 |
| Galleon | 32098 |
| Nalak | 32518 |
| Oondasta | 32519 |
| Celestials | 33117 |
| Ordos | 33118 |

Data is stored in `WTF/Account/<account>/SavedVariables/WorldBossChecklist.lua` and persists across sessions.

## FAQ

**Q: Why isn't my character showing up?**
A: Make sure you've logged into that character at least once with the addon enabled. The addon only records data for characters you actually play.

**Q: Can I track bosses for characters on different accounts?**
A: No, the addon only tracks characters on the same WoW account due to how SavedVariables work.

**Q: The boss shows as killed but I haven't killed it this week?**
A: This can happen if the weekly reset wasn't detected properly. Try `/reload` or wait for the next login after reset.

**Q: How do I remove a deleted character from the list?**
A: Right-click the character and select "Delete" or "Ban" (if you don't want it to reappear).

## Compatibility

- **Game Version**: Classic Mists of Pandaria 5.5.3 (Interface 65302)
- **Dependencies**: None (standalone addon)

## Credits

- Inspired by [Merfin's World Boss Checklist WeakAura](https://wago.io/worldboss_checklist)
- Addon created with assistance from Claude

## License

This addon is provided as-is for personal use. Feel free to modify for your own needs.

## Changelog

### v1.0.0
- Initial release
- Track all 6 MoP world bosses
- Character grouping by realm
- Delete/ban character functionality
- Configurable boss tracking
- Level filtering
- Weekly reset detection
