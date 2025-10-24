local hsapp = hs.application
local hsscreen = hs.screen
local hsgeom = hs.geometry

-- Adjust these for your setup
local bigScreen = hsscreen.find("Studio Display") or hsscreen.allScreens()[2]
local smallScreen = hsscreen.find("Built-in Retina Display") or hsscreen.primaryScreen()

------------------------------------------------------
-- Helper: open new iTerm window, move it, and run cmd
------------------------------------------------------
local function newITermWindow(screen, frame, command)
    if not screen then return end

    local screenFrame = screen:frame()
    local x = math.floor(screenFrame.x + (frame.x * screenFrame.w))
    local y = math.floor(screenFrame.y + (frame.y * screenFrame.h))
    local w = math.floor(frame.w * screenFrame.w)
    local h = math.floor(frame.h * screenFrame.h)

    -- Use AppleScript to create window AND position it
    hs.task.new("/usr/bin/osascript", function(exitCode, stdout, stderr)
        -- AppleScript handles the positioning, so we're done
    end, {
        "-e", 'tell application "iTerm"',
        "-e", 'create window with default profile',
        "-e", 'tell current window',
        "-e", 'set bounds to {' .. x .. ', ' .. y .. ', ' .. (x + w) .. ', ' .. (y + h) .. '}',
        "-e", 'tell current session',
        "-e", 'write text "' .. command .. '"',
        "-e", 'end tell',
        "-e", 'end tell',
        "-e", 'end tell'
    }):start()
end

------------------------------------------------------
-- Layout setup
------------------------------------------------------
local function layoutTerminals()
    -- 6 terminals on laptop screen (2 columns x 3 rows)
    local rows, cols = 2, 3
    local idx = 0
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            idx = idx + 1
            local frame = {x = c / cols, y = r / rows, w = 1 / cols, h = 1 / rows}
            hs.timer.doAfter(0.5 * idx, function()
                -- newITermWindow(smallScreen, frame, "q")
                newITermWindow(smallScreen, frame, "q && claude --permission-mode plan")
            end)
        end
    end

    -- 2 terminals on Studio Display (right side, stacked vertically)
    local bigFrames = {
        {x = 0.75, y = 0, w = 0.25, h = 0.5},
        {x = 0.75, y = 0.5, w = 0.25, h = 0.5},
    }
    for i, frame in ipairs(bigFrames) do
        hs.timer.doAfter(0.5 * (idx + i), function()
            newITermWindow(bigScreen, frame, "q")
        end)
    end
end


------------------------------------------------------
-- VS Code positioning
------------------------------------------------------
local function openVSCode()
    if not bigScreen then return end

    local quickliPath = os.getenv("HOME") .. "/quickli/web"
    local screenFrame = bigScreen:frame()
    local x = math.floor(screenFrame.x)
    local y = math.floor(screenFrame.y)
    local w = math.floor(0.75 * screenFrame.w)
    local h = math.floor(screenFrame.h)

    hs.task.new("/usr/local/bin/code", nil, {"--new-window", quickliPath}):start()

    -- Use Hammerspoon to position the window with "web" in title
    hs.timer.doAfter(2, function()
        local app = hsapp.find("Code")
        if not app then return end

        local targetWin = nil
        for _, win in ipairs(app:allWindows()) do
            local title = win:title() or ""
            if string.find(title:lower(), "web") then
                targetWin = win
                break
            end
        end

        if targetWin then
            targetWin:setFrame(hsgeom.rect(x, y, w, h))
        end
    end)
end

------------------------------------------------------
-- Export module
------------------------------------------------------
return {
    run = function()
        layoutTerminals()
        -- Wait for iTerm windows to finish (8 windows × 0.5s = 4s, plus buffer)
        hs.timer.doAfter(5, function()
            openVSCode()
        end)
    end
}
