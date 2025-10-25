-- Window Manager
-- Simple, reliable window management to replace Rectangle

local M = {}

-- State tracking for cycling behavior
local windowState = {}

------------------------------------------------------
-- Core window positioning functions
------------------------------------------------------

-- Get the focused window and screen
local function getFocusedWindowAndScreen()
    local win = hs.window.focusedWindow()
    if not win then return nil, nil end
    local screen = win:screen()
    return win, screen
end

-- Position window to a fraction of the screen
local function positionWindow(win, screen, x, y, w, h)
    if not win or not screen then return end

    local frame = screen:frame()
    local targetFrame = {
        x = frame.x + (x * frame.w),
        y = frame.y + (y * frame.h),
        w = w * frame.w,
        h = h * frame.h
    }

    win:setFrame(targetFrame, 0)  -- 0 = instant, no animation
end

-- Check if window frame approximately matches target (with tolerance for floating point)
local function frameMatches(win, screen, x, y, w, h, tolerance)
    tolerance = tolerance or 0.01
    local screenFrame = screen:frame()
    local winFrame = win:frame()

    local expectedX = screenFrame.x + (x * screenFrame.w)
    local expectedY = screenFrame.y + (y * screenFrame.h)
    local expectedW = w * screenFrame.w
    local expectedH = h * screenFrame.h

    return math.abs(winFrame.x - expectedX) < tolerance * screenFrame.w and
           math.abs(winFrame.y - expectedY) < tolerance * screenFrame.h and
           math.abs(winFrame.w - expectedW) < tolerance * screenFrame.w and
           math.abs(winFrame.h - expectedH) < tolerance * screenFrame.h
end

------------------------------------------------------
-- Cycling width functions (Cmd+Opt+1 through 5)
------------------------------------------------------

-- Generic cycling function for horizontal positioning
local function cycleHorizontal(width, positions)
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    -- Find current position in the cycle
    for i, pos in ipairs(positions) do
        if frameMatches(win, screen, pos.x, 0, width, 1) then
            -- Move to next position in cycle
            local nextPos = positions[(i % #positions) + 1]
            positionWindow(win, screen, nextPos.x, 0, width, 1)
            return
        end
    end

    -- Not in any known position, start with first position
    positionWindow(win, screen, positions[1].x, 0, width, 1)
end

-- Cmd+Opt+1: 3/4 width (cycles left/right)
function M.threeQuarterWidth()
    cycleHorizontal(0.75, {{x = 0}, {x = 0.25}})
end

-- Cmd+Opt+2: 2/3 width (cycles left/right)
function M.twoThirdWidth()
    cycleHorizontal(2/3, {{x = 0}, {x = 1/3}})
end

-- Cmd+Opt+3: 1/2 width (cycles left/right)
function M.halfWidth()
    cycleHorizontal(0.5, {{x = 0}, {x = 0.5}})
end

-- Cmd+Opt+4: 1/3 width (cycles left/middle/right)
function M.oneThirdWidth()
    cycleHorizontal(1/3, {{x = 0}, {x = 1/3}, {x = 2/3}})
end

-- Cmd+Opt+5: 1/4 width (cycles left/middle-left/middle-right/right)
function M.oneQuarterWidth()
    cycleHorizontal(0.25, {{x = 0}, {x = 0.25}, {x = 0.5}, {x = 0.75}})
end

------------------------------------------------------
-- Smart arrow navigation
------------------------------------------------------

-- Right arrow: Move right, or to next screen if already on right
function M.smartRight()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    -- Check if window is on right half
    if frameMatches(win, screen, 0.5, 0, 0.5, 1) then
        -- Move to next screen, left side
        local nextScreen = screen:next()
        positionWindow(win, nextScreen, 0, 0, 0.5, 1)
    else
        -- Move to right half of current screen
        positionWindow(win, screen, 0.5, 0, 0.5, 1)
    end
end

-- Left arrow: Move left, or to previous screen if already on left
function M.smartLeft()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    -- Check if window is on left half
    if frameMatches(win, screen, 0, 0, 0.5, 1) then
        -- Move to previous screen, right side
        local prevScreen = screen:previous()
        positionWindow(win, prevScreen, 0.5, 0, 0.5, 1)
    else
        -- Move to left half of current screen
        positionWindow(win, screen, 0, 0, 0.5, 1)
    end
end

------------------------------------------------------
-- Vertical cycling with width preservation
------------------------------------------------------

-- Up arrow: Cycle through top half -> top third -> bottom third -> middle third -> ...
function M.smartUp()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local winFrame = win:frame()
    local screenFrame = screen:frame()
    local currentWidth = winFrame.w / screenFrame.w

    -- Check current vertical position
    if frameMatches(win, screen, winFrame.x / screenFrame.w, 0, currentWidth, 0.5) then
        -- From top half -> top third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0, currentWidth, 1/3)
    elseif frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0, currentWidth, 1/3) then
        -- From top third -> bottom third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 2/3, currentWidth, 1/3)
    elseif frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 2/3, currentWidth, 1/3) then
        -- From bottom third -> middle third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 1/3, currentWidth, 1/3)
    elseif frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 1/3, currentWidth, 1/3) then
        -- From middle third -> top third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0, currentWidth, 1/3)
    else
        -- Default: top half
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0, currentWidth, 0.5)
    end
end

-- Down arrow: Cycle through bottom half -> bottom third -> top third -> middle third -> ...
function M.smartDown()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local winFrame = win:frame()
    local screenFrame = screen:frame()
    local currentWidth = winFrame.w / screenFrame.w

    -- Check current vertical position
    if frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0.5, currentWidth, 0.5) then
        -- From bottom half -> bottom third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 2/3, currentWidth, 1/3)
    elseif frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 2/3, currentWidth, 1/3) then
        -- From bottom third -> top third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0, currentWidth, 1/3)
    elseif frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0, currentWidth, 1/3) then
        -- From top third -> middle third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 1/3, currentWidth, 1/3)
    elseif frameMatches(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 1/3, currentWidth, 1/3) then
        -- From middle third -> bottom third
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 2/3, currentWidth, 1/3)
    else
        -- Default: bottom half
        positionWindow(win, screen, (winFrame.x - screenFrame.x) / screenFrame.w, 0.5, currentWidth, 0.5)
    end
end

------------------------------------------------------
-- Maximize
------------------------------------------------------

function M.maximize()
    local win, screen = getFocusedWindowAndScreen()
    positionWindow(win, screen, 0, 0, 1, 1)
end

------------------------------------------------------
-- Bind hotkeys
------------------------------------------------------

function M.bindHotkeys()
    local mash = {"cmd", "alt"}

    -- Number keys: cycling width positions
    hs.hotkey.bind(mash, "1", M.threeQuarterWidth)
    hs.hotkey.bind(mash, "2", M.twoThirdWidth)
    hs.hotkey.bind(mash, "3", M.halfWidth)
    hs.hotkey.bind(mash, "4", M.oneThirdWidth)
    hs.hotkey.bind(mash, "5", M.oneQuarterWidth)

    -- Enter: Maximize
    hs.hotkey.bind(mash, "return", M.maximize)

    -- Arrows: Smart navigation
    hs.hotkey.bind(mash, "right", M.smartRight)
    hs.hotkey.bind(mash, "left", M.smartLeft)
    hs.hotkey.bind(mash, "up", M.smartUp)
    hs.hotkey.bind(mash, "down", M.smartDown)

    hs.alert.show("Window Manager loaded")
end

return M
