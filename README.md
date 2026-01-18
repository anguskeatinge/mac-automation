# Mac Automation

Hammerspoon configuration for window management and workspace automation.

## Features

### Window Manager
Smart, keyboard-driven window management that replaces Rectangle.

**Number Keys (Cmd+Opt+1-5)** - Cycle through width positions:
- `1` - 3/4 width (left/right)
- `2` - 2/3 width (left/right)
- `3` - 1/2 width (left/right)
- `4` - 1/3 width (left/middle/right)
- `5` - 1/4 width (4 positions)

**Arrow Keys** - Progressive positioning:
- `Left/Right` - Half screen → Full height → Move to next screen
- `Up/Down` - Move vertical position → Full width

**WASD** - Advanced layout control:
- `W/S` - Cycle vertical thirds
- `A/D` - Move/cycle horizontal with width preservation
- `Q/E` - Quick screen cycling

**Extras:**
- `Enter` - Maximize

### Dev Layout
One-key workspace setup with `Cmd+Opt+Ctrl+T`:
- Opens 6 iTerm windows on laptop (2x3 grid)
- Opens 2 iTerm windows on external display
- Opens VS Code on external display
- All positioned and ready to go

## Installation

1. Install [Hammerspoon](https://www.hammerspoon.org/): `brew install --cask hammerspoon`
2. Clone this repo wherever you want (e.g., `~/mac-automation`)
3. Point Hammerspoon to it by creating `~/.hammerspoon/init.lua`:
```lua
-- ~/.hammerspoon/init.lua
-- Point to the main configuration in ~/mac-automation
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/mac-automation/?.lua"
package.path = package.path .. ";" .. home .. "/mac-automation/?/init.lua"
require("hammerspoon_config")
```
4. Reload Hammerspoon config

## Usage

Edit `hammerspoon_config.lua` to customize hotkeys and behavior.

Adjust screen names in `dev_layout.lua` to match your setup.

## Menu Bar Stats

System stats displayed in separate menu bar items:
- **CPU** - Click for top 10 processes by CPU usage (with kill option)
- **RAM** - Click for top 10 processes by memory (with kill option)
- **Network** - Click for network-active processes
- **Battery** - Click to toggle caffeine (prevent sleep)
- **Timer** - Pomodoro timer + clipboard history

### Adding a New Menubar Module

1. Create `angus_scripts/menubar/yourmodule.lua`
2. Follow the pattern in existing modules (cpu.lua, ram.lua)
3. Register in `angus_scripts/menubar/init.lua`
4. Add tests in `tests/menubar/yourmodule_spec.lua`

## Testing

Run all tests:
```bash
busted tests/
```

## CRITICAL: Menubar Width Bug (MacBooks with Notch)

If menubar items appear intermittently or disappear, **check the title width first**.

macOS miscalculates the width of certain characters (especially emoji and some Unicode),
treating them as wider than they render. On MacBooks with a notch, this causes items
to be "hidden" behind the notch even when they would visually fit.

**Debugging this cost hours.** Before suspecting GC or other issues, always verify:
1. Are titles using emoji or special Unicode? Try plain ASCII.
2. Are titles long? Shorten them.
3. Do items appear on initial load then vanish? Classic width miscalculation.

**What works:**
- Plain ASCII: `12`, `4G`, `P`
- Simple arrows: `↓` seems OK

**What breaks:**
- Emoji: `⚙`, `🔋`, `⏱`, `▦`
- Combined: `⚙ 12%`, `🔋85%`

## Hammerspoon Best Practices

### Preventing Garbage Collection
Hammerspoon objects (menubars, timers, watchers) can disappear if Lua's garbage collector
decides they're no longer referenced. Always store these in **global variables**:

```lua
-- WRONG - will be garbage collected
local myMenubar = hs.menubar.new()

-- CORRECT - persists for lifetime of Hammerspoon
myMenubar = hs.menubar.new()

-- ALSO CORRECT - use a global registry table
_G.myRefs = _G.myRefs or {}
_G.myRefs.menubar = hs.menubar.new()
```

See: [Hammerspoon Wiki on GC](https://github.com/asmagill/hammerspoon/wiki/Variable-Scope-and-Garbage-Collection)

### Debug tip
Force GC to test stability:
```lua
-- In Hammerspoon console:
collectgarbage()
collectgarbage()
```

## Note

This repo isn't meant to live in `~/.hammerspoon` directly. Instead, it lives in its own location (like `~/mac-automation`) and you point to it from Hammerspoon's init file using the snippet above.
