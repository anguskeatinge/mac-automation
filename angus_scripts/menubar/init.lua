-- Menu Bar Orchestrator
-- Creates all menubars and manages refresh timer

local M = {}

-- Load submodules
local cpu = require("angus_scripts.menubar.cpu")
local ram = require("angus_scripts.menubar.ram")
local network = require("angus_scripts.menubar.network")
local battery = require("angus_scripts.menubar.battery")
local pomodoro = require("angus_scripts.menubar.pomodoro")

-- State
M._state = {
    refreshTimer = nil,
}

-- Expose submodules for direct access if needed
M.cpu = cpu
M.ram = ram
M.network = network
M.battery = battery
M.pomodoro = pomodoro

-- Global registry to prevent garbage collection of Hammerspoon objects
-- See: https://github.com/asmagill/hammerspoon/wiki/Variable-Scope-and-Garbage-Collection
_G._hammerspoon_menubar_refs = _G._hammerspoon_menubar_refs or {}

-- Check and recover missing menubars
local function recoverMissingMenubars()
    local recovered = false

    if not cpu._state.menubar then
        print("[menubar] CPU menubar was nil, recreating")
        cpu.create()
        _G._hammerspoon_menubar_refs.cpu = cpu.menubar
        recovered = true
    end

    if not ram._state.menubar then
        print("[menubar] RAM menubar was nil, recreating")
        ram.create()
        _G._hammerspoon_menubar_refs.ram = ram.menubar
        recovered = true
    end

    if not network._state.menubar then
        print("[menubar] Network menubar was nil, recreating")
        network.create()
        _G._hammerspoon_menubar_refs.network = network.menubar
        recovered = true
    end

    if not battery._state.menubar then
        print("[menubar] Battery menubar was nil, recreating")
        battery.create()
        _G._hammerspoon_menubar_refs.battery = battery.menubar
        recovered = true
    end

    if not pomodoro._state.menubar then
        print("[menubar] Pomodoro menubar was nil, recreating")
        pomodoro.create()
        _G._hammerspoon_menubar_refs.pomodoro = pomodoro.menubar
        recovered = true
    end

    return recovered
end

-- Refresh all menubar displays with per-module error logging
function M.refresh()
    -- Check and recover any missing menubars first
    recoverMissingMenubars()

    -- Refresh each module individually with error logging
    local modules = {
        {name = "cpu", mod = cpu},
        {name = "ram", mod = ram},
        {name = "network", mod = network},
        {name = "battery", mod = battery},
        {name = "pomodoro", mod = pomodoro},
    }

    for _, m in ipairs(modules) do
        local ok, err = pcall(m.mod.refresh)
        if not ok then
            print(string.format("[menubar] %s refresh error: %s", m.name, tostring(err)))
        end
    end
end

-- Start all menubars
function M.start()
    -- Create menubars (rightmost first, so order is: CPU RAM Net Battery Pomodoro)
    pomodoro.create()
    battery.create()
    network.create()
    ram.create()
    cpu.create()

    -- Store ALL references in global registry to prevent GC
    _G._hammerspoon_menubar_refs = {
        cpu = cpu.menubar,
        ram = ram.menubar,
        network = network.menubar,
        battery = battery.menubar,
        pomodoro = pomodoro.menubar,
    }

    -- Start refresh timer (every 2 seconds)
    M._state.refreshTimer = hs.timer.doEvery(2, function()
        pcall(M.refresh)
    end)
    -- Store in global registry
    _G._hammerspoon_menubar_refs.refreshTimer = M._state.refreshTimer
    -- Keep extra reference on module
    M.refreshTimer = M._state.refreshTimer

    -- Store clipboard watcher reference
    if pomodoro.clipboardWatcher then
        _G._hammerspoon_menubar_refs.clipboardWatcher = pomodoro.clipboardWatcher
    end

    -- Initial refresh
    M.refresh()
end

-- Stop all menubars
function M.stop()
    if M._state.refreshTimer then
        M._state.refreshTimer:stop()
        M._state.refreshTimer = nil
    end

    cpu.destroy()
    ram.destroy()
    network.destroy()
    battery.destroy()
    pomodoro.destroy()
end

-- Reset for testing
function M.reset()
    M.stop()
    cpu.reset()
    ram.reset()
    network.reset()
    battery.reset()
    pomodoro.reset()
end

return M
