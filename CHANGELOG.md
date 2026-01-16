# Changelog

All notable changes to the Weeklies Tracker addon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-01-16

### Added
- **Valor point tracking** - Track weekly valor progress across all characters
- **Tabbed main window** - Switch between "Bosses" and "Valor" tabs
- **Valor tab** - Shows character name, current valor, and weekly progress (x/1600)
- **Color-coded valor progress** - Green (capped), Yellow (>=50%), Orange (<50%)
- **Valor settings tab** - New settings tab for valor-specific options
- **"Show Not Capped Only" filter** - Hide characters that have reached the weekly valor cap
- **New slash commands** - `/wt`, `/weeklies`, `/weekliestracker`
- **Valor slash commands** - `/wt valor` to switch to valor tab, `/wt notcapped` to toggle filter
- **Minimap tooltip valor display** - Shows current character's valor progress on hover
- **Titan Panel valor display** - Shows valor progress in button text
- **Automatic data migration** - Migrates data from WorldBossChecklistDB to WeekliesTrackerDB

### Changed
- **Renamed addon** - From "World Boss Checklist" to "Weeklies Tracker"
- **Renamed folder** - From `WorldBossChecklist` to `WeekliesTracker`
- **New SavedVariables name** - Now uses `WeekliesTrackerDB` (migrates from old DB automatically)
- **Settings panel** - Now has 4 tabs: General, Bosses, Valor, Characters
- **Updated print prefix** - Now shows `[WT]` instead of `[WBC]`
- **Frame names updated** - `WeekliesTrackerFrame`, `WeekliesTrackerMinimapButton`, etc.

### Backward Compatibility
- **Legacy slash commands work** - `/wbc`, `/worldboss`, `/worldbosschecklist` still function
- **Data migration** - Old `WorldBossChecklistDB` data is automatically migrated on first load

## [1.1.0] - 2026-01-14

### Added
- **Tabbed settings panel** - Settings are now organized into three tabs: General, Bosses, and Characters
- **Character management tab** - View all tracked characters, delete or ban them directly from settings
- **Titan Panel support** - Full integration with Titan Panel addon (shows unkilled boss count, tooltip with details, right-click menu)
- **Unban All button** - Quickly unban all previously banned characters from the Characters tab

### Changed
- **Minimap icon** - Changed to skull raid marker icon which displays correctly in all WoW versions
- **Settings panel size** - Increased to 400x450 pixels for better readability
- **Slider width** - Increased to 200 pixels for easier adjustment
- **Boss checkboxes** - Now show zone information next to each boss name

### Fixed
- **Minimap icon appearing as black circle** - Replaced achievement icon with guaranteed-to-exist raid target icon

## [1.0.1] - 2026-01-14

### Added
- **Minimap button** - Click to toggle the main window, right-click for settings, drag to reposition around the minimap (uses Sha of Anger icon)
- **Settings panel** - GUI for all configuration options (accessible via minimap right-click, settings button in header, or `/wbc config`)
- **Settings button** in the main window header (gear icon next to close button)

### Changed
- **Boss column headers** now show full boss names (Sha of Anger, Galleon, Nalak, etc.) instead of abbreviations
- **Removed scrollbar** - The window now dynamically grows/shrinks based on content
- Increased boss column width from 35 to 65 pixels to accommodate full names
- Window width now adjusts automatically based on enabled bosses

### Fixed
- Boss header tooltips now properly reuse existing frames instead of creating new ones each update

## [1.0.0] - 2026-01-14

### Added
- Initial release
- Track all 6 MoP world bosses:
  - Sha of Anger (Kun-Lai Summit)
  - Galleon (Valley of the Four Winds)
  - Nalak (Isle of Thunder)
  - Oondasta (Isle of Giants)
  - Celestials (Timeless Isle)
  - Ordos (Timeless Isle)
- Multi-character tracking across all realms
- Characters grouped by realm with collapsible sections
- Weekly reset detection and automatic data clearing
- Character management:
  - Right-click to delete or ban characters
  - Banned characters won't be re-added on login
- Configurable options:
  - Toggle individual boss tracking
  - Show unkilled only filter
  - Minimum level filter
  - UI scale adjustment
  - Lock frame position
- Slash commands (`/wbc`, `/worldboss`)
- Class-colored character names
- Movable, scalable window
- Position saving across sessions
