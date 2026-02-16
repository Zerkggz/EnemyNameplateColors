# Enemy Nameplate Colors

A lightweight World of Warcraft addon that dynamically colors enemy nameplates and cast bars based on unit type, threat level, and cast importance.

## Features

- **Dynamic Health Bar Color Coding**: Nameplates change color based on:
  - Unit type (Boss, Mini-Boss, Caster, Standard)
  - Threat status (different for Tanks vs DPS/Healers)
  - Combat status

- **Dynamic Cast Bar Color Coding**: Enemy cast bars change color based on:
  - Spell importance (uses Blizzard's IsSpellImportant API)
  - Interruptibility (standard, uninterruptible, channeled)

- **Role-Aware**: Automatically detects your role (Tank, DPS, or Healer) and applies appropriate threat colors

- **Fully Customizable**: All colors can be customized via the in-game options panel, including alpha transparency for cast bars

- **Lightweight**: Minimal performance impact, hooks directly into Blizzard's nameplate system

## Installation

1. Extract the `EnemyNameplateColors` folder to your WoW addons directory:
   - **Retail**: `World of Warcraft\_retail_\Interface\AddOns\`
   - **Classic**: `World of Warcraft\_classic_\Interface\AddOns\`

2. Restart World of Warcraft or reload UI (`/reload`)

3. The addon will automatically load

### Opening Options

- Type `/enc` or `/enemynameplatecolors` in chat
- Or navigate to: ESC → Interface → AddOns → Enemy Nameplate Colors

### Customizing Colors

1. Open the options panel (`/enc`)
2. Click any color swatch to open the color picker
3. Choose your preferred color and alpha (transparency)
4. Changes apply immediately to all nameplates
5. Click "Reset to Defaults" to restore original colors
6. Use the "Enable Cast Bar Coloring" checkbox to toggle cast bar colors on/off

## Default Colors

### Unit Types (Health Bars)
- **Boss**: #CC33FF (Purple)
- **Mini-Boss**: #3366FF (Blue)
- **Caster**: #00CCFF (Cyan)
- **Standard**: #CC99FF (Light Purple)

### Tank Threats (Health Bars)
- **On Other Tank**: #4896FF (Blue)
- **No Threat**: #FF0000 (Red)
- **Losing Threat**: #FF9900 (Orange)

### DPS/Healer Threats (Health Bars)
- **Has Threat**: #FF0000 (Red)
- **Gaining Threat**: #FF9900 (Orange)

### Cast Bars
- **Important Spell**: #FF00FF (Magenta) - Highest priority
- **Uninterruptible**: #808080 (Gray) - Cannot interrupt
- **Channel**: #00FF00 (Green) - Channeled spell
- **Standard**: #FFB300 (Gold) - Normal interruptible cast

## Compatibility

- **Interface Version**: 12.0.0 (The War Within / Midnight)
- Compatible with default Blizzard nameplates
- May conflict with other nameplate addons (KUI, Plater, TidyPlates, etc.)
- Uses Midnight-safe APIs - no taint issues

## Commands

- `/enc` - Open options panel
- `/enemynameplatecolors` - Open options panel
- `/reload` - Reload UI to refresh settings

## Support

For issues or suggestions:
- Check compatibility with other nameplate addons
- Ensure you're running the latest version
- Post detailed bug reports with error messages

## Credits

Created for World of Warcraft players who want better visual feedback on enemy nameplates and cast bars without the overhead of full nameplate replacement addons.

## License

Free to use and modify for personal use.

## Changelog

### Version 1.1.0
- Added cast bar coloring system
- Added detection for important spells (Blizzard API)
- Added detection for player-targeted spells
- Added alpha transparency support for cast bar colors
- Added enable/disable toggle for cast bar coloring
- Midnight-safe implementation (no taint)

### Version 1.0.0
- Initial release
- Health bar coloring based on unit type and threat
- Tank vs DPS/Healer role detection
- Customizable color options
