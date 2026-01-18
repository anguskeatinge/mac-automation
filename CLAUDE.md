# Mac Automation - Claude Context

## Project Structure

```
mac-automation/
├── hammerspoon_config.lua    # Main entry point, loads all modules
├── angus_scripts/
│   ├── dev_layout.lua        # Multi-window workspace setup
│   ├── window_manager.lua    # Keyboard-driven window management
│   ├── slack_page_up_down.lua
│   ├── vscode_chrome_ctrl_opt_L_R.lua
│   └── menubar/              # Menu bar stat modules (one per file)
│       ├── init.lua          # Orchestrator - creates menubars, manages refresh
│       ├── cpu.lua           # CPU stats + top processes dropdown
│       ├── ram.lua           # RAM stats + top processes dropdown
│       ├── network.lua       # Network stats + active connections dropdown
│       ├── battery.lua       # Battery + caffeine toggle dropdown
│       ├── pomodoro.lua      # Timer + clipboard history dropdown
│       └── utils.lua         # Shared: formatBytes, truncateText, etc.
├── tests/
│   ├── mocks/
│   │   └── hs_mock.lua       # Hammerspoon API mock
│   ├── window_manager_spec.lua
│   └── menubar/              # Per-module test files
│       ├── utils_spec.lua
│       ├── cpu_spec.lua
│       ├── ram_spec.lua
│       ├── network_spec.lua
│       ├── battery_spec.lua
│       ├── pomodoro_spec.lua
│       └── init_spec.lua
└── README.md
```

## Module Pattern

Each menubar module follows this pattern:

```lua
local M = {}
local utils = require("angus_scripts.menubar.utils")

-- Injectable dependencies (for testing)
M._deps = {
    executeCommand = function(cmd) return hs.execute(cmd) end,
}

-- State specific to this module
M._state = { menubar = nil, ... }

-- Pure functions (testable)
function M.formatSomething() end
function M.parseSomething() end

-- Menu builder (called on click)
function M.buildMenu() end

-- Create and return menubar
function M.create()
    M._state.menubar = hs.menubar.new()
    M._state.menubar:setMenu(M.buildMenu)
    return M._state.menubar
end

-- Update title (called by refresh timer)
function M.refresh() end

-- Cleanup
function M.destroy() end

-- Reset for testing
function M.reset() end

return M
```

## Testing

Run all tests:
```bash
busted tests/
```

Run specific test file:
```bash
busted tests/menubar/cpu_spec.lua
```

Mocks: `tests/mocks/hs_mock.lua` provides full Hammerspoon API mock including:
- hs.menubar
- hs.timer
- hs.host (cpuUsageTicks, vmStat)
- hs.battery
- hs.caffeinate
- hs.pasteboard
- hs.notify
- hs.execute

## Adding Features

### New Menubar Item
1. Create new file in `angus_scripts/menubar/`
2. Follow the module pattern above
3. Register in `angus_scripts/menubar/init.lua`:
   - Add require at top
   - Call create() in start()
   - Call refresh() in refresh()
   - Call destroy() in stop()
   - Call reset() in reset()
4. Add tests in `tests/menubar/yourmodule_spec.lua`

### New Hotkey
Add to `hammerspoon_config.lua`:
```lua
hs.hotkey.bind({"cmd", "alt"}, "X", function()
    -- your code
end)
```

### New Window Layout
Modify `angus_scripts/window_manager.lua`

## Key Commands Used

- `ps aux -r | tail -n +2 | head -n 10` - Top 10 processes by CPU (~40ms)
- `ps aux -m | tail -n +2 | head -n 10` - Top 10 processes by memory (~40ms)
- `nettop -P -l1 2>/dev/null | tail -n +2 | head -n 10` - Network active processes (~13ms)
- `netstat -ib` - Network interface bytes for speed calculation

## Design Decisions

- **Separate menubars**: Each stat has its own menubar item for clarity
- **Fixed-width network display**: Prevents width jumping (padded to 5 chars)
- **Injectable dependencies**: All external calls (hs.*, os.*) are injectable for testing
- **Clock icon (⏱️)**: Used instead of tomato for pomodoro timer
- **Kill process submenu**: Each process in CPU/RAM dropdown has kill option

## Gotchas

### Garbage Collection
Hammerspoon uses Lua's garbage collector. Objects created with `hs.menubar.new()`,
`hs.timer.doEvery()`, etc. will be destroyed if not held in a **global variable**.

The pattern `local M = {}; M.menubar = hs.menubar.new(); return M` is NOT sufficient
because `M` itself is local and can be collected.

**Solution:** Use `_G._hammerspoon_menubar_refs` global registry in init.lua to hold
all persistent references.

**Debug tip:** Force GC to test stability:
```lua
collectgarbage()
collectgarbage()
```

See: [Hammerspoon Wiki on GC](https://github.com/asmagill/hammerspoon/wiki/Variable-Scope-and-Garbage-Collection)
