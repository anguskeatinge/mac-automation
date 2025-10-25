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
package.path = package.path .. ";" .. os.getenv("HOME") .. "/mac-automation/?.lua"
require("hammerspoon_config")
```
4. Reload Hammerspoon config

## Usage

Edit `hammerspoon_config.lua` to customize hotkeys and behavior.

Adjust screen names in `dev_layout.lua` to match your setup.

## Note

This repo isn't meant to live in `~/.hammerspoon` directly. Instead, it lives in its own location (like `~/mac-automation`) and you point to it from Hammerspoon's init file using the snippet above.
