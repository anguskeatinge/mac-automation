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
-- Helper functions for position detection (must be before cycleHorizontal)
------------------------------------------------------

-- Helper to get current width ratio
local function getWidthRatio(win, screen)
    local winFrame = win:frame()
    local screenFrame = screen:frame()
    return winFrame.w / screenFrame.w
end

------------------------------------------------------
-- Cycling width functions (Cmd+Opt+1 through 5)
------------------------------------------------------

-- Generic cycling function with right-side width preservation
local function cycleHorizontal(width, positions)
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = (win:frame().x - screen:frame().x) / screen:frame().w
    local w = getWidthRatio(win, screen)
    local rightEdge = 1 - width

    -- Special case: on right side with DIFFERENT width -> stay right with new width
    -- Check if currently right-aligned (x ≈ 1 - current_width) and different target width
    -- BUT exclude full width windows (treat those as left-aligned)
    if math.abs(x - (1 - w)) < 0.01 and math.abs(w - width) > 0.01 and math.abs(w - 1) > 0.01 then
        positionWindow(win, screen, rightEdge, 0, width, 1)
        return
    end

    -- Normal cycling logic (original behavior)
    -- Find current position in the cycle
    for i, pos in ipairs(positions) do
        if frameMatches(win, screen, pos.x, 0, width, 1) then
            -- Move to next position in cycle
            local nextPos = positions[(i % #positions) + 1]
            positionWindow(win, screen, nextPos.x, 0, width, 1)
            return
        end
    end

    -- Not in any known position, start with first position (left)
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
-- Additional helper functions for arrow navigation
------------------------------------------------------

-- Helper to get normalized x position
local function getNormalizedX(win, screen)
    local winFrame = win:frame()
    local screenFrame = screen:frame()
    return (winFrame.x - screenFrame.x) / screenFrame.w
end

-- Helper to get current height ratio
local function getHeightRatio(win, screen)
    local winFrame = win:frame()
    local screenFrame = screen:frame()
    return winFrame.h / screenFrame.h
end

------------------------------------------------------
-- Smart arrow navigation
------------------------------------------------------

-- Right arrow: Progressive - right half (keep height) -> full height -> next screen
function M.smartRight()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local h = getHeightRatio(win, screen)
    local y = (win:frame().y - screen:frame().y) / screen:frame().h

    -- Step 3: If at right half with full height -> move to next screen left half
    if frameMatches(win, screen, 0.5, 0, 0.5, 1) then
        local nextScreen = screen:next()
        positionWindow(win, nextScreen, 0, 0, 0.5, 1)
    -- Step 2: If at right half but not full height -> make full height
    elseif frameMatches(win, screen, 0.5, y, 0.5, h) then
        positionWindow(win, screen, 0.5, 0, 0.5, 1)
    -- Step 1: Any other position -> move to right half, keep current height
    else
        positionWindow(win, screen, 0.5, y, 0.5, h)
    end
end

-- Left arrow: Progressive - left half (keep height) -> full height -> previous screen
function M.smartLeft()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local h = getHeightRatio(win, screen)
    local y = (win:frame().y - screen:frame().y) / screen:frame().h

    -- Step 3: If at left half with full height -> move to previous screen right half
    if frameMatches(win, screen, 0, 0, 0.5, 1) then
        local prevScreen = screen:previous()
        positionWindow(win, prevScreen, 0.5, 0, 0.5, 1)
    -- Step 2: If at left half but not full height -> make full height
    elseif frameMatches(win, screen, 0, y, 0.5, h) then
        positionWindow(win, screen, 0, 0, 0.5, 1)
    -- Step 1: Any other position -> move to left half, keep current height
    else
        positionWindow(win, screen, 0, y, 0.5, h)
    end
end

------------------------------------------------------
-- Vertical cycling with width preservation
------------------------------------------------------

-- Up arrow: Move up, second press makes full width
function M.smartUp()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = getNormalizedX(win, screen)
    local w = getWidthRatio(win, screen)
    local h = getHeightRatio(win, screen)

    -- Already at top and full width - do nothing (idempotent)
    if frameMatches(win, screen, 0, 0, 1, 1) or
       frameMatches(win, screen, 0, 0, 1, 0.5) or
       frameMatches(win, screen, 0, 0, 1, 1/3) or
       frameMatches(win, screen, 0, 0, 1, 2/3) then
        return
    -- At top but not full width - make full width
    elseif frameMatches(win, screen, x, 0, w, 0.5) or
           frameMatches(win, screen, x, 0, w, 1/3) or
           frameMatches(win, screen, x, 0, w, 2/3) then
        positionWindow(win, screen, 0, 0, 1, h)
    -- At middle third -> jump to top third
    elseif frameMatches(win, screen, x, 1/3, w, 1/3) then
        positionWindow(win, screen, x, 0, w, 1/3)
    -- At bottom half -> jump to top half
    elseif frameMatches(win, screen, x, 0.5, w, 0.5) then
        positionWindow(win, screen, x, 0, w, 0.5)
    -- At bottom third -> jump to middle third
    elseif frameMatches(win, screen, x, 2/3, w, 1/3) then
        positionWindow(win, screen, x, 1/3, w, 1/3)
    -- At bottom 2/3 -> jump to top 2/3
    elseif frameMatches(win, screen, x, 1/3, w, 2/3) then
        positionWindow(win, screen, x, 0, w, 2/3)
    else
        -- Any other position -> snap to top half
        positionWindow(win, screen, x, 0, w, 0.5)
    end
end

-- Down arrow: Move down, second press makes full width
function M.smartDown()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = getNormalizedX(win, screen)
    local w = getWidthRatio(win, screen)
    local h = getHeightRatio(win, screen)

    -- Already at bottom and full width - do nothing (idempotent)
    if frameMatches(win, screen, 0, 0, 1, 1) or
       frameMatches(win, screen, 0, 0.5, 1, 0.5) or
       frameMatches(win, screen, 0, 2/3, 1, 1/3) or
       frameMatches(win, screen, 0, 1/3, 1, 2/3) then
        return
    -- At bottom but not full width - make full width, keep y position
    elseif frameMatches(win, screen, x, 0.5, w, 0.5) then
        positionWindow(win, screen, 0, 0.5, 1, 0.5)
    elseif frameMatches(win, screen, x, 2/3, w, 1/3) then
        positionWindow(win, screen, 0, 2/3, 1, 1/3)
    elseif frameMatches(win, screen, x, 1/3, w, 2/3) then
        positionWindow(win, screen, 0, 1/3, 1, 2/3)
    -- At middle third -> jump to bottom third
    elseif frameMatches(win, screen, x, 1/3, w, 1/3) then
        positionWindow(win, screen, x, 2/3, w, 1/3)
    -- At top half -> jump to bottom half
    elseif frameMatches(win, screen, x, 0, w, 0.5) then
        positionWindow(win, screen, x, 0.5, w, 0.5)
    -- At top third -> jump to middle third
    elseif frameMatches(win, screen, x, 0, w, 1/3) then
        positionWindow(win, screen, x, 1/3, w, 1/3)
    -- At top 2/3 -> jump to bottom 2/3
    elseif frameMatches(win, screen, x, 0, w, 2/3) then
        positionWindow(win, screen, x, 1/3, w, 2/3)
    else
        -- Any other position -> snap to bottom half
        positionWindow(win, screen, x, 0.5, w, 0.5)
    end
end

------------------------------------------------------
-- WASD horizontal cycling with quarters (stays on same screen)
------------------------------------------------------

-- W: Cycle up through thirds at current horizontal position
function M.wasdUp()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = getNormalizedX(win, screen)
    local w = getWidthRatio(win, screen)
    local h = getHeightRatio(win, screen)

    -- Cycle through heights at top: full -> 2/3 -> 1/2 -> 1/3 -> full -> ...
    if frameMatches(win, screen, x, 0, w, 1) then
        -- At full height -> go to 2/3
        positionWindow(win, screen, x, 0, w, 2/3)
    elseif frameMatches(win, screen, x, 0, w, 2/3) then
        -- At 2/3 -> go to 1/2
        positionWindow(win, screen, x, 0, w, 0.5)
    elseif frameMatches(win, screen, x, 0, w, 0.5) then
        -- At 1/2 -> go to 1/3
        positionWindow(win, screen, x, 0, w, 1/3)
    elseif frameMatches(win, screen, x, 0, w, 1/3) then
        -- At 1/3 -> cycle back to full height
        positionWindow(win, screen, x, 0, w, 1)
    -- Check if at middle (y=1/3, height=1/3)
    elseif frameMatches(win, screen, x, 1/3, w, 1/3) then
        -- At middle third -> jump to top third
        positionWindow(win, screen, x, 0, w, 1/3)
    -- Check if at bottom positions
    elseif frameMatches(win, screen, x, 0.5, w, 0.5) then
        -- At bottom half -> jump to top half
        positionWindow(win, screen, x, 0, w, 0.5)
    elseif frameMatches(win, screen, x, 2/3, w, 1/3) then
        -- At bottom third -> jump to middle third
        positionWindow(win, screen, x, 1/3, w, 1/3)
    elseif frameMatches(win, screen, x, 1/3, w, 2/3) then
        -- At bottom 2/3 -> jump to top 2/3
        positionWindow(win, screen, x, 0, w, 2/3)
    else
        -- Any other position -> snap to top half
        positionWindow(win, screen, x, 0, w, 0.5)
    end
end

-- S: Cycle down through thirds at current horizontal position
function M.wasdDown()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = getNormalizedX(win, screen)
    local w = getWidthRatio(win, screen)
    local h = getHeightRatio(win, screen)

    -- Cycle through heights at bottom: full -> 2/3 -> 1/2 -> 1/3 -> full -> ...
    if frameMatches(win, screen, x, 0, w, 1) then
        -- At full height -> go to 2/3
        positionWindow(win, screen, x, 1/3, w, 2/3)
    elseif frameMatches(win, screen, x, 1/3, w, 2/3) then
        -- At 2/3 -> go to 1/2
        positionWindow(win, screen, x, 0.5, w, 0.5)
    elseif frameMatches(win, screen, x, 0.5, w, 0.5) then
        -- At 1/2 -> go to bottom 1/3
        positionWindow(win, screen, x, 2/3, w, 1/3)
    elseif frameMatches(win, screen, x, 2/3, w, 1/3) then
        -- At bottom 1/3 -> cycle back to full height
        positionWindow(win, screen, x, 0, w, 1)
    -- Check if at middle (y=1/3, height=1/3)
    elseif frameMatches(win, screen, x, 1/3, w, 1/3) then
        -- At middle third -> jump to bottom third
        positionWindow(win, screen, x, 2/3, w, 1/3)
    -- Check if at top positions
    elseif frameMatches(win, screen, x, 0, w, 0.5) then
        -- At top half -> jump to bottom half
        positionWindow(win, screen, x, 0.5, w, 0.5)
    elseif frameMatches(win, screen, x, 0, w, 1/3) then
        -- At top third -> jump to middle third
        positionWindow(win, screen, x, 1/3, w, 1/3)
    elseif frameMatches(win, screen, x, 0, w, 2/3) then
        -- At top 2/3 -> jump to bottom 2/3
        positionWindow(win, screen, x, 1/3, w, 2/3)
    else
        -- Any other position -> snap to bottom half
        positionWindow(win, screen, x, 0.5, w, 0.5)
    end
end

-- A: Move left or cycle through widths on left side
-- Cycle: 1/2 -> 1/3 -> 1/4 -> 3/4 -> 2/3 -> 1/2
function M.wasdLeft()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = getNormalizedX(win, screen)
    local w = getWidthRatio(win, screen)
    local y = (win:frame().y - screen:frame().y) / screen:frame().h
    local h = getHeightRatio(win, screen)

    -- Check if already at left edge (x ≈ 0)
    if math.abs(x) < 0.01 then
        -- Already on left side, cycle through widths: full -> 3/4 -> 2/3 -> 1/2 -> 1/3 -> 1/4 -> full -> ...
        if frameMatches(win, screen, 0, y, 1, h) then
            -- At full width -> go to 3/4
            positionWindow(win, screen, 0, y, 0.75, h)
        elseif frameMatches(win, screen, 0, y, 0.75, h) then
            -- At 3/4 -> go to 2/3
            positionWindow(win, screen, 0, y, 2/3, h)
        elseif frameMatches(win, screen, 0, y, 2/3, h) then
            -- At 2/3 -> go to 1/2
            positionWindow(win, screen, 0, y, 0.5, h)
        elseif frameMatches(win, screen, 0, y, 0.5, h) then
            -- At 1/2 -> go to 1/3
            positionWindow(win, screen, 0, y, 1/3, h)
        elseif frameMatches(win, screen, 0, y, 1/3, h) then
            -- At 1/3 -> go to 1/4
            positionWindow(win, screen, 0, y, 0.25, h)
        elseif frameMatches(win, screen, 0, y, 0.25, h) then
            -- At 1/4 -> cycle back to full width
            positionWindow(win, screen, 0, y, 1, h)
        else
            -- Any other width -> start with full
            positionWindow(win, screen, 0, y, 1, h)
        end
    -- Not at left edge - move left based on width
    elseif w >= 0.5 then
        -- Width 1/2 or larger -> jump all the way to left
        positionWindow(win, screen, 0, y, w, h)
    elseif math.abs(w - 1/3) < 0.01 then
        -- Width 1/3 -> move left one third
        positionWindow(win, screen, math.max(0, x - 1/3), y, w, h)
    elseif math.abs(w - 0.25) < 0.01 then
        -- Width 1/4 -> move left one quarter
        positionWindow(win, screen, math.max(0, x - 0.25), y, w, h)
    else
        -- Any other size -> jump to left
        positionWindow(win, screen, 0, y, w, h)
    end
end

-- D: Move right or cycle through widths on right side
-- Cycle: 1/2 -> 1/3 -> 1/4 -> 3/4 -> 2/3 -> 1/2
function M.wasdRight()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local x = getNormalizedX(win, screen)
    local w = getWidthRatio(win, screen)
    local y = (win:frame().y - screen:frame().y) / screen:frame().h
    local h = getHeightRatio(win, screen)

    -- Check if already at right edge (x ≈ 1 - w)
    if math.abs(x - (1 - w)) < 0.01 then
        -- Already on right side, cycle through widths: full -> 3/4 -> 2/3 -> 1/2 -> 1/3 -> 1/4 -> full -> ...
        if frameMatches(win, screen, 0, y, 1, h) then
            -- At full width -> go to 3/4
            positionWindow(win, screen, 0.25, y, 0.75, h)
        elseif frameMatches(win, screen, 0.25, y, 0.75, h) then
            -- At 3/4 -> go to 2/3
            positionWindow(win, screen, 1/3, y, 2/3, h)
        elseif frameMatches(win, screen, 1/3, y, 2/3, h) then
            -- At 2/3 -> go to 1/2
            positionWindow(win, screen, 0.5, y, 0.5, h)
        elseif frameMatches(win, screen, 0.5, y, 0.5, h) then
            -- At 1/2 -> go to 1/3
            positionWindow(win, screen, 2/3, y, 1/3, h)
        elseif frameMatches(win, screen, 2/3, y, 1/3, h) then
            -- At 1/3 -> go to 1/4
            positionWindow(win, screen, 0.75, y, 0.25, h)
        elseif frameMatches(win, screen, 0.75, y, 0.25, h) then
            -- At 1/4 -> cycle back to full width
            positionWindow(win, screen, 0, y, 1, h)
        else
            -- Any other width -> start with full
            positionWindow(win, screen, 0, y, 1, h)
        end
    -- Not at right edge - move right based on width
    elseif w >= 0.5 then
        -- Width 1/2 or larger -> jump all the way to right
        positionWindow(win, screen, 1 - w, y, w, h)
    elseif math.abs(w - 1/3) < 0.01 then
        -- Width 1/3 -> move right one third
        positionWindow(win, screen, math.min(1 - w, x + 1/3), y, w, h)
    elseif math.abs(w - 0.25) < 0.01 then
        -- Width 1/4 -> move right one quarter
        positionWindow(win, screen, math.min(1 - w, x + 0.25), y, w, h)
    else
        -- Any other size -> jump to right
        positionWindow(win, screen, 1 - w, y, w, h)
    end
end

------------------------------------------------------
-- Q/E: Simple screen cycling (same as arrow keys)
------------------------------------------------------

-- Q: Progressive - left half (keep height) -> full height -> previous screen (same as Left arrow)
function M.cycleScreenQ()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local h = getHeightRatio(win, screen)
    local y = (win:frame().y - screen:frame().y) / screen:frame().h

    -- Step 3: If at left half with full height -> move to previous screen right half
    if frameMatches(win, screen, 0, 0, 0.5, 1) then
        local prevScreen = screen:previous()
        positionWindow(win, prevScreen, 0.5, 0, 0.5, 1)
    -- Step 2: If at left half but not full height -> make full height
    elseif frameMatches(win, screen, 0, y, 0.5, h) then
        positionWindow(win, screen, 0, 0, 0.5, 1)
    -- Step 1: Any other position -> move to left half, keep current height
    else
        positionWindow(win, screen, 0, y, 0.5, h)
    end
end

-- E: Progressive - right half (keep height) -> full height -> next screen (same as Right arrow)
function M.cycleScreenE()
    local win, screen = getFocusedWindowAndScreen()
    if not win or not screen then return end

    local h = getHeightRatio(win, screen)
    local y = (win:frame().y - screen:frame().y) / screen:frame().h

    -- Step 3: If at right half with full height -> move to next screen left half
    if frameMatches(win, screen, 0.5, 0, 0.5, 1) then
        local nextScreen = screen:next()
        positionWindow(win, nextScreen, 0, 0, 0.5, 1)
    -- Step 2: If at right half but not full height -> make full height
    elseif frameMatches(win, screen, 0.5, y, 0.5, h) then
        positionWindow(win, screen, 0.5, 0, 0.5, 1)
    -- Step 1: Any other position -> move to right half, keep current height
    else
        positionWindow(win, screen, 0.5, y, 0.5, h)
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

    -- Backtick: Maximize (alternative)
    hs.hotkey.bind(mash, "`", M.maximize)

    -- Arrows: Smart navigation (basic, non-cycling up/down)
    hs.hotkey.bind(mash, "right", M.smartRight)
    hs.hotkey.bind(mash, "left", M.smartLeft)
    hs.hotkey.bind(mash, "up", M.smartUp)
    hs.hotkey.bind(mash, "down", M.smartDown)

    -- WASD: Advanced navigation (cycling vertical thirds, horizontal quarters)
    hs.hotkey.bind(mash, "w", M.wasdUp)
    hs.hotkey.bind(mash, "s", M.wasdDown)
    hs.hotkey.bind(mash, "a", M.wasdLeft)
    hs.hotkey.bind(mash, "d", M.wasdRight)

    -- Q/E: Cycle window to next screen with same position
    hs.hotkey.bind(mash, "q", M.cycleScreenQ)
    hs.hotkey.bind(mash, "e", M.cycleScreenE)

    hs.alert.show("Window Manager loaded")
end

return M
