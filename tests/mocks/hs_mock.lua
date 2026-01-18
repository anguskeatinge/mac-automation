-- Hammerspoon API Mock for testing
-- This module provides mock implementations of hs.window, hs.screen, hs.hotkey, hs.alert,
-- and system stats APIs (host, battery, caffeinate, menubar, timer, fs, pasteboard, notify)

local M = {}

-- Storage for test state
M._state = {
    focusedWindow = nil,
    screens = {},
    hotkeys = {},
    lastSetFrame = nil,
    -- System stats state
    cpuTicks = { overall = { user = 100, system = 50, nice = 10, idle = 840, active = 160 }, n = 8 },
    vmStat = { pageSize = 4096, pagesWiredDown = 500000, pagesActive = 1000000, pagesInactive = 300000, pagesFree = 200000 },
    batteryPercentage = 75,
    batteryTimeRemaining = 180,
    batteryIsCharging = false,
    batteryIsCharged = false,
    batteryHealth = "Good",
    batteryTimeToFullCharge = -1,
    caffeineState = {},
    menubars = {},
    timers = {},
    volumeInfo = { ["/"] = { NSURLVolumeTotalCapacityKey = 500000000000, NSURLVolumeAvailableCapacityKey = 150000000000 } },
    pasteboardWatchers = {},
    pasteboardContents = "",
    notifications = {},
    executeResults = {},
}

-- Reset all state between tests
function M.reset()
    M._state = {
        focusedWindow = nil,
        screens = {},
        hotkeys = {},
        lastSetFrame = nil,
        -- System stats state
        cpuTicks = { overall = { user = 100, system = 50, nice = 10, idle = 840, active = 160 }, n = 8 },
        vmStat = { pageSize = 4096, pagesWiredDown = 500000, pagesActive = 1000000, pagesInactive = 300000, pagesFree = 200000 },
        batteryPercentage = 75,
        batteryTimeRemaining = 180,
        batteryIsCharging = false,
        batteryIsCharged = false,
        batteryHealth = "Good",
        batteryTimeToFullCharge = -1,
        caffeineState = {},
        menubars = {},
        timers = {},
        volumeInfo = { ["/"] = { NSURLVolumeTotalCapacityKey = 500000000000, NSURLVolumeAvailableCapacityKey = 150000000000 } },
        pasteboardWatchers = {},
        pasteboardContents = "",
        notifications = {},
        executeResults = {},
    }
end

------------------------------------------------------
-- Mock Screen
------------------------------------------------------

local function createMockScreen(config)
    local screen = {}
    screen._frame = config.frame or { x = 0, y = 0, w = 1920, h = 1080 }
    screen._nextScreen = nil
    screen._prevScreen = nil

    function screen:frame()
        return {
            x = self._frame.x,
            y = self._frame.y,
            w = self._frame.w,
            h = self._frame.h,
        }
    end

    function screen:next()
        return self._nextScreen or self
    end

    function screen:previous()
        return self._prevScreen or self
    end

    return screen
end

------------------------------------------------------
-- Mock Window
------------------------------------------------------

local function createMockWindow(config)
    local window = {}
    window._frame = config.frame or { x = 0, y = 0, w = 960, h = 540 }
    window._screen = config.screen

    function window:frame()
        return {
            x = self._frame.x,
            y = self._frame.y,
            w = self._frame.w,
            h = self._frame.h,
        }
    end

    function window:setFrame(frame, duration)
        self._frame = {
            x = frame.x,
            y = frame.y,
            w = frame.w,
            h = frame.h,
        }
        M._state.lastSetFrame = self._frame
    end

    function window:screen()
        return self._screen
    end

    return window
end

------------------------------------------------------
-- Test Setup Helpers
------------------------------------------------------

-- Create a single screen setup (most common)
function M.setupSingleScreen(screenFrame)
    local screen = createMockScreen({ frame = screenFrame or { x = 0, y = 0, w = 1920, h = 1080 } })
    screen._nextScreen = screen
    screen._prevScreen = screen
    M._state.screens = { screen }
    return screen
end

-- Create a dual screen setup
function M.setupDualScreens(screen1Frame, screen2Frame)
    local screen1 = createMockScreen({ frame = screen1Frame or { x = 0, y = 0, w = 1920, h = 1080 } })
    local screen2 = createMockScreen({ frame = screen2Frame or { x = 1920, y = 0, w = 1920, h = 1080 } })
    screen1._nextScreen = screen2
    screen1._prevScreen = screen2
    screen2._nextScreen = screen1
    screen2._prevScreen = screen1
    M._state.screens = { screen1, screen2 }
    return screen1, screen2
end

-- Set up a focused window with given frame on given screen
function M.setFocusedWindow(frame, screen)
    local window = createMockWindow({
        frame = frame,
        screen = screen,
    })
    M._state.focusedWindow = window
    return window
end

-- Get the last frame that was set (for assertions)
function M.getLastSetFrame()
    return M._state.lastSetFrame
end

------------------------------------------------------
-- hs.window module
------------------------------------------------------

M.window = {}

function M.window.focusedWindow()
    return M._state.focusedWindow
end

------------------------------------------------------
-- hs.hotkey module
------------------------------------------------------

M.hotkey = {}

function M.hotkey.bind(modifiers, key, fn)
    table.insert(M._state.hotkeys, {
        modifiers = modifiers,
        key = key,
        fn = fn,
    })
end

-- Get recorded hotkeys (for assertions)
function M.getHotkeys()
    return M._state.hotkeys
end

-- Find a hotkey by key
function M.findHotkey(key)
    for _, hk in ipairs(M._state.hotkeys) do
        if hk.key == key then
            return hk
        end
    end
    return nil
end

------------------------------------------------------
-- hs.alert module
------------------------------------------------------

M.alert = {}

function M.alert.show(message)
    -- No-op for tests
end

------------------------------------------------------
-- hs.host module
------------------------------------------------------

M.host = {}

function M.host.cpuUsageTicks()
    return M._state.cpuTicks
end

function M.host.vmStat()
    return M._state.vmStat
end

-- Test helpers for host
function M.setCpuTicks(ticks)
    M._state.cpuTicks = ticks
end

function M.setVmStat(stats)
    M._state.vmStat = stats
end

------------------------------------------------------
-- hs.battery module
------------------------------------------------------

M.battery = {}

function M.battery.percentage()
    return M._state.batteryPercentage
end

function M.battery.timeRemaining()
    return M._state.batteryTimeRemaining
end

function M.battery.isCharging()
    return M._state.batteryIsCharging
end

function M.battery.isCharged()
    return M._state.batteryIsCharged
end

function M.battery.health()
    return M._state.batteryHealth
end

function M.battery.timeToFullCharge()
    return M._state.batteryTimeToFullCharge
end

-- Test helpers for battery
function M.setBatteryPercentage(pct)
    M._state.batteryPercentage = pct
end

function M.setBatteryTimeRemaining(minutes)
    M._state.batteryTimeRemaining = minutes
end

function M.setBatteryIsCharging(charging)
    M._state.batteryIsCharging = charging
end

function M.setBatteryIsCharged(charged)
    M._state.batteryIsCharged = charged
end

function M.setBatteryHealth(health)
    M._state.batteryHealth = health
end

function M.setBatteryTimeToFullCharge(minutes)
    M._state.batteryTimeToFullCharge = minutes
end

------------------------------------------------------
-- hs.caffeinate module
------------------------------------------------------

M.caffeinate = {}

function M.caffeinate.set(sleepType, value, keepActive)
    M._state.caffeineState[sleepType] = value
end

function M.caffeinate.get(sleepType)
    return M._state.caffeineState[sleepType] or false
end

-- Test helper
function M.getCaffeineState()
    return M._state.caffeineState
end

------------------------------------------------------
-- hs.menubar module
------------------------------------------------------

M.menubar = {}

local function createMockMenubar()
    local mb = {
        _title = "",
        _menu = nil,
        _deleted = false,
        _inMenuBar = true,
    }

    function mb:setTitle(title)
        self._title = title
    end

    function mb:title()
        return self._title
    end

    function mb:setMenu(menuTable)
        self._menu = menuTable
    end

    function mb:menu()
        return self._menu
    end

    function mb:delete()
        self._deleted = true
        self._inMenuBar = false
    end

    function mb:returnToMenuBar()
        self._inMenuBar = true
    end

    function mb:isInMenuBar()
        return self._inMenuBar
    end

    table.insert(M._state.menubars, mb)
    return mb
end

function M.menubar.new()
    return createMockMenubar()
end

-- Test helper
function M.getMenubars()
    return M._state.menubars
end

------------------------------------------------------
-- hs.timer module
------------------------------------------------------

M.timer = {}

local function createMockTimer(interval, fn)
    local t = {
        _interval = interval,
        _fn = fn,
        _running = true,
    }

    function t:stop()
        self._running = false
    end

    function t:start()
        self._running = true
    end

    function t:fire()
        if self._fn then
            self._fn()
        end
    end

    table.insert(M._state.timers, t)
    return t
end

function M.timer.doEvery(interval, fn)
    return createMockTimer(interval, fn)
end

function M.timer.doAfter(delay, fn)
    return createMockTimer(delay, fn)
end

-- Test helper
function M.getTimers()
    return M._state.timers
end

------------------------------------------------------
-- hs.fs module
------------------------------------------------------

M.fs = {}
M.fs.volume = {}

function M.fs.volume.allVolumes(showHidden)
    return M._state.volumeInfo
end

-- Test helper
function M.setVolumeInfo(info)
    M._state.volumeInfo = info
end

------------------------------------------------------
-- hs.pasteboard module
------------------------------------------------------

M.pasteboard = {}
M.pasteboard.watcher = {}

local function createMockPasteboardWatcher(fn)
    local w = {
        _fn = fn,
        _running = false,
    }

    function w:start()
        self._running = true
    end

    function w:stop()
        self._running = false
    end

    table.insert(M._state.pasteboardWatchers, w)
    return w
end

function M.pasteboard.watcher.new(fn)
    return createMockPasteboardWatcher(fn)
end

function M.pasteboard.setContents(text)
    M._state.pasteboardContents = text
end

function M.pasteboard.getContents()
    return M._state.pasteboardContents
end

-- Test helper
function M.getPasteboardWatchers()
    return M._state.pasteboardWatchers
end

function M.simulatePasteboardChange(text)
    M._state.pasteboardContents = text
    for _, w in ipairs(M._state.pasteboardWatchers) do
        if w._running and w._fn then
            w._fn(text)
        end
    end
end

------------------------------------------------------
-- hs.notify module
------------------------------------------------------

M.notify = {}

local function createMockNotification(attributes)
    local n = {
        _attributes = attributes or {},
        _sent = false,
    }

    function n:title(t)
        if t then
            self._attributes.title = t
            return self
        end
        return self._attributes.title
    end

    function n:informativeText(t)
        if t then
            self._attributes.informativeText = t
            return self
        end
        return self._attributes.informativeText
    end

    function n:send()
        self._sent = true
        table.insert(M._state.notifications, self)
        return self
    end

    return n
end

function M.notify.new(attributes)
    return createMockNotification(attributes)
end

-- Test helper
function M.getNotifications()
    return M._state.notifications
end

------------------------------------------------------
-- hs.eventtap module
------------------------------------------------------

M.eventtap = {}

function M.eventtap.keyStroke(modifiers, key)
    -- No-op for tests, but could track if needed
end

------------------------------------------------------
-- hs.execute function
------------------------------------------------------

function M.execute(cmd, withPath)
    local result = M._state.executeResults[cmd]
    if result then
        return result.output, result.status, result.type, result.rc
    end
    return "", false, "exit", 1
end

-- Test helper
function M.setExecuteResult(cmd, output, status, resultType, rc)
    M._state.executeResults[cmd] = {
        output = output or "",
        status = status ~= false,
        type = resultType or "exit",
        rc = rc or 0,
    }
end

return M
