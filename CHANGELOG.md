## v1.1.2

### New Features
- **Focus Target Highlighting**: Two options for highlighting your focus target's nameplate — color the health bar, or apply a texture overlay. Both use a shared color picker with alpha support. Disabled by default.

### Bug Fixes
- **Tapped Units**: Tapped units now show Blizzard's default grey color instead of addon colors.
- **Interrupt Border vs Cast Bar Toggle**: Interrupt-ready border now works independently of the "Enable Cast Bar Coloring" toggle.
- **Cast Bar Toggle**: Toggling cast bar options now takes effect immediately without requiring a reload.

### Changes
- Cast bar coloring and interrupt borders now only activate when the player is in combat. This avoids Midnight secret value issues that caused incorrect interruptible/uninterruptible colors on enemy casts when the player was out of combat.