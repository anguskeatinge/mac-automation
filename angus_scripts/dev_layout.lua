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
    hs.task.new("/usr/bin/osascript", nil, {
        "-e", 'tell application "iTerm"',
        "-e", 'create window with default profile',
        "-e", 'tell current session of current window',
        "-e", 'write text "' .. command .. '"',
        "-e", 'end tell',
        "-e", 'end tell'
    }):start()

    hs.timer.doAfter(1.0, function()
        local app = hsapp.find("iTerm")
        if app then
            local win = app:mainWindow()
            if win and screen then
                local screenFrame = screen:frame()
                local absoluteFrame = hsgeom.rect(
                    screenFrame.x + (frame.x * screenFrame.w),
                    screenFrame.y + (frame.y * screenFrame.h),
                    frame.w * screenFrame.w,
                    frame.h * screenFrame.h
                )
                win:moveToScreen(screen)
                win:setFrame(absoluteFrame)
            end
        end
    end)
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
            hs.timer.doAfter(0.8 * idx, function()
                newITermWindow(smallScreen, frame, "q")
                -- newITermWindow(smallScreen, frame, "q && claude --permission-mode plan")
            end)
        end
    end

    -- 2 terminals on Studio Display (right side, stacked vertically)
    local bigFrames = {
        {x = 0.75, y = 0, w = 0.25, h = 0.5},
        {x = 0.75, y = 0.5, w = 0.25, h = 0.5},
    }
    for i, frame in ipairs(bigFrames) do
        hs.timer.doAfter(0.8 * (idx + i), function()
            newITermWindow(bigScreen, frame, "q")
        end)
    end
end


------------------------------------------------------
-- VS Code positioning
------------------------------------------------------
local function openVSCode()
    local quickliPath = os.getenv("HOME") .. "/quickli/web"
    hs.task.new("/usr/local/bin/code", nil, {"--new-window", quickliPath}):start()
    hs.timer.doAfter(1, function()
        local app = hs.application.find("Visual Studio Code")
        if app then
            local win = app:mainWindow()
            if win and bigScreen then
                local screenFrame = bigScreen:frame()
                local absoluteFrame = hsgeom.rect(
                    screenFrame.x,
                    screenFrame.y + (0.25 * screenFrame.h),
                    0.75 * screenFrame.w,
                    0.75 * screenFrame.h
                )
                win:moveToScreen(bigScreen)
                win:setFrame(absoluteFrame)
            end
        end
    end)
end

-- local function openVSCode()
--     hs.application.launchOrFocus("Visual Studio Code")
--     hs.timer.doAfter(1, function()
--         local win = hsapp.find("Visual Studio Code"):mainWindow()
--         if win then
--             win:moveToScreen(bigScreen)
--             win:setFrame(hsgeom.rect(0, 0, 0.75, 1)) -- 3/4 width
--         end
--     end)
-- end

------------------------------------------------------
-- Export module
------------------------------------------------------
return {
    run = function()
        layoutTerminals()
        openVSCode()
    end
}
