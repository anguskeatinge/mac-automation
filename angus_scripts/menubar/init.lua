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
    recoveryCount = 0,  -- Track how often menubars need recovery
}

-- Expose submodules for direct access if needed
M.cpu = cpu
M.ram = ram
M.network = network
M.battery = battery
M.pomodoro = pomodoro

-- Global registry to prevent garbage collection of Hammerspoon objects
-- See: https://github.com/asmagill/hammerspoon/wiki/Variable-Scope-and-Garbage-Collection
-- Initialized fresh in start() to avoid stale references on reload

-- Check and recover missing menubars (indicates GC collected them)
local function recoverMissingMenubars()
    local missing = {}
    local mb

    if not cpu._state.menubar then
        mb = cpu.create()
        _G._hammerspoon_menubar_refs.cpu = mb
        table.insert(missing, "cpu")
    end

    if not ram._state.menubar then
        mb = ram.create()
        _G._hammerspoon_menubar_refs.ram = mb
        table.insert(missing, "ram")
    end

    if not network._state.menubar then
        mb = network.create()
        _G._hammerspoon_menubar_refs.network = mb
        table.insert(missing, "network")
    end

    if not battery._state.menubar then
        mb = battery.create()
        _G._hammerspoon_menubar_refs.battery = mb
        table.insert(missing, "battery")
    end

    if not pomodoro._state.menubar then
        mb = pomodoro.create()
        _G._hammerspoon_menubar_refs.pomodoro = mb
        table.insert(missing, "pomodoro")
    end

    if #missing > 0 then
        M._state.recoveryCount = M._state.recoveryCount + 1
        print(string.format("[menubar] Recovery #%d: recreated %s",
            M._state.recoveryCount, table.concat(missing, ", ")))
    end

    return #missing > 0
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
    -- Use rawset to bypass any metamethods and ensure direct table storage
    rawset(_G, "_hammerspoon_menubar_refs", {})

    -- Create all menubars and store BOTH the raw menubar AND keep module reference
    -- Order: first = rightmost, last = leftmost

    local refs = _G._hammerspoon_menubar_refs

    -- Create each one and immediately store in multiple places
    -- Order: first = rightmost, last = leftmost
    refs.pomodoro = pomodoro.create()
    pomodoro._persistent = refs.pomodoro

    refs.battery = battery.create()
    battery._persistent = refs.battery

    refs.ram = ram.create()
    ram._persistent = refs.ram

    refs.cpu = cpu.create()
    cpu._persistent = refs.cpu

    refs.network = network.create()
    network._persistent = refs.network  -- leftmost

    -- Also store on M
    M._menubars = {
        network = refs.network,
        pomodoro = refs.pomodoro,
        battery = refs.battery,
        ram = refs.ram,
        cpu = refs.cpu,
    }

    -- Start refresh timer
    M._state.refreshTimer = hs.timer.doEvery(2, function()
        pcall(M.refresh)
    end)
    refs.refreshTimer = M._state.refreshTimer
    M.refreshTimer = M._state.refreshTimer

    -- Store clipboard watcher reference
    if pomodoro.clipboardWatcher then
        refs.clipboardWatcher = pomodoro.clipboardWatcher
    end

    -- Initial refresh
    M.refresh()

    -- Force all menubars to (re)register with macOS (same order as creation)
    refs.pomodoro:returnToMenuBar()
    refs.battery:returnToMenuBar()
    refs.ram:returnToMenuBar()
    refs.cpu:returnToMenuBar()
    refs.network:returnToMenuBar()
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
    M._state.recoveryCount = 0
    cpu.reset()
    ram.reset()
    network.reset()
    battery.reset()
    pomodoro.reset()
end

return M
