## v1.1.3

### New Features
- **Purgeable Buff Glow**: Adds a colored glow to stealable/purgeable enemy buffs on nameplates. Covers Spellsteal, Purge, Consume Magic, and similar abilities. Configurable glow color and toggle in the options panel. Enabled by default.

### Bug Fixes
- **Interrupt Border on Non-Interruptible Casts**: Fixed the interrupt-ready border sometimes showing on casts that are not interruptible, particularly in Open World. The addon now treats a nil interruptible state as non-interruptible instead of defaulting to showing the border.
- **Interrupt Border Showing Out of Combat**: Fixed the interrupt-ready border persisting when the player was not in combat but an enemy was casting. The border is now always hidden outside of player combat, regardless of the cast bar coloring toggle.
- **Interrupt Border Cooldown Refresh**: Fixed interrupt-ready border not updating on cooldown changes when cast bar coloring was disabled. The interruptible state is now cached independently of the cast bar color toggle.
- **Neutral Mob Filtering**: Neutral enemies (yellow nameplates) now correctly show Blizzard's default color instead of being colored as casters or other unit types.

### Performance
- **Threat Event Filtering**: Threat events (`UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE`) now update only the affected nameplate when the event targets a specific unit, instead of refreshing all visible nameplates on every threat tick.
- **Cooldown Event Early-Out**: `SPELL_UPDATE_COOLDOWN` now skips processing entirely when the player is out of combat or has no interrupt spells known, avoiding unnecessary iteration on every GCD.
- **Tank Cache**: Other tank unit IDs in the group are now cached and updated on roster changes, instead of iterating all group members on every nameplate color update. The cache rebuilds on `GROUP_ROSTER_UPDATE`.

### Changes
- Replaced all `UnitIsEnemy` checks with `UnitIsFriend`-based filtering to avoid silent failures from secret boolean values in Blizzard's hook execution paths.
- Removed unused `HexToRGB` and `RGBToHex` utility functions.

## v1.1.2

### New Features
- **Focus Target Highlighting**: Two options for highlighting your focus target's nameplate — color the health bar, or apply a texture overlay. Both use a shared color picker with alpha support. Disabled by default.

### Bug Fixes
- **Tapped Units**: Tapped units now show Blizzard's default grey color instead of addon colors.
- **Interrupt Border vs Cast Bar Toggle**: Interrupt-ready border now works independently of the "Enable Cast Bar Coloring" toggle.
- **Cast Bar Toggle**: Toggling cast bar options now takes effect immediately without requiring a reload.

### Changes
- Cast bar coloring and interrupt borders now only activate when the player is in combat. This avoids Midnight secret value issues that caused incorrect interruptible/uninterruptible colors on enemy casts when the player was out of combat.