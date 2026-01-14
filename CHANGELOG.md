# Changelog

All notable changes to the World Boss Checklist addon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
