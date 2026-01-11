-- Hammerspoon API Mock for testing
-- This module provides mock implementations of hs.window, hs.screen, hs.hotkey, and hs.alert

local M = {}

-- Storage for test state
M._state = {
    focusedWindow = nil,
    screens = {},
    hotkeys = {},
    lastSetFrame = nil,
}

-- Reset all state between tests
function M.reset()
    M._state = {
        focusedWindow = nil,
        screens = {},
        hotkeys = {},
        lastSetFrame = nil,
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

return M
