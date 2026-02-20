## v1.1.0

### New Features
- **Zone Selection**: Choose where the addon is active — Dungeons, Raids, Delves/Scenarios, and Open World. Configurable via checkboxes in the options panel.
- **Custom Cast Bar Textures**: Nameplate cast bars now use custom desaturated textures, allowing the color picker to fully control cast bar colors instead of tinting over Blizzard's default atlas.
- **Interrupt Ready Overlay**: Replaced the pixel border with a glow texture overlay for the interrupt-ready indicator.
- **Debug Command**: `/enc debug` while targeting an enemy prints its classification, power type, level, and ENC unit type to chat — useful for identifying how enemies are categorized.

### Bug Fixes
- **Midnight Compatibility**: Fixed secret boolean/number taint errors caused by `UnitDetailedThreatSituation`, `UnitIsSpellTarget`, `isHighlightedCastTarget`, and `C_Spell.GetSpellCooldownDuration` returning secret values. Threat logic now uses `UnitThreatSituation`; cast bar and interrupt checks use `C_CurveUtil.EvaluateColorValueFromBoolean` throughout.
- **Multiple Interrupt Support**: Warlock and other multi-interrupt classes now correctly show the interrupt-ready indicator if *any* known interrupt is off cooldown.
- **Cast Bar Scope**: Cast bar texture and color changes now correctly apply only to nameplate cast bars — target and focus frame cast bars are no longer affected.

### Changes
- Cast bar color alphas now default to 100% (was 75%).
- Uninterruptible cast default color changed to #464646.
- Delves and Scenarios merged into a single toggle (both use the "scenario" instance type).
