-- Pomodoro Menu Bar Module
-- Timer functionality + clipboard history dropdown

local M = {}
local utils = require("angus_scripts.menubar.utils")

-- Injectable dependencies (for testing)
M._deps = {
    getTime = function() return os.time() end,
    pasteboardSetContents = function(text) return hs.pasteboard.setContents(text) end,
    keyStroke = function(mods, key) return hs.eventtap.keyStroke(mods, key) end,
    notify = function(title, text)
        return hs.notify.new():title(title):informativeText(text):send()
    end,
}

-- State specific to this module
M._state = {
    menubar = nil,
    pomodoroEndTime = nil,
    pomodoroMode = nil,  -- "work" or "break"
    pomodoroTimer = nil,
    clipboardHistory = {},
    clipboardWatcher = nil,
}

-- Handle pomodoro completion
function M.onPomodoroComplete()
    local message
    if M._state.pomodoroMode == "work" then
        message = "Work session complete! Time for a break."
    else
        message = "Break over! Ready to work?"
    end

    M._deps.notify("Pomodoro", message)

    M._state.pomodoroEndTime = nil
    M._state.pomodoroMode = nil
    if M._state.pomodoroTimer then
        M._state.pomodoroTimer:stop()
        M._state.pomodoroTimer = nil
    end
end

-- Start a pomodoro work session (25 minutes)
function M.startPomodoroWork()
    local duration = 25 * 60  -- 25 minutes
    M._state.pomodoroEndTime = M._deps.getTime() + duration
    M._state.pomodoroMode = "work"

    if M._state.pomodoroTimer then
        M._state.pomodoroTimer:stop()
    end
    M._state.pomodoroTimer = hs.timer.doEvery(1, function()
        M.refresh()
    end)
end

-- Start a pomodoro break session (5 minutes)
function M.startPomodoroBreak()
    local duration = 5 * 60  -- 5 minutes
    M._state.pomodoroEndTime = M._deps.getTime() + duration
    M._state.pomodoroMode = "break"

    if M._state.pomodoroTimer then
        M._state.pomodoroTimer:stop()
    end
    M._state.pomodoroTimer = hs.timer.doEvery(1, function()
        M.refresh()
    end)
end

-- Stop pomodoro
function M.stopPomodoro()
    M._state.pomodoroEndTime = nil
    M._state.pomodoroMode = nil
    if M._state.pomodoroTimer then
        M._state.pomodoroTimer:stop()
        M._state.pomodoroTimer = nil
    end
end

-- Handle clipboard change
function M.onClipboardChange(text)
    utils.addToClipboardHistory(text, M._state.clipboardHistory, 10)
end

-- Paste item from clipboard history
function M.pasteHistoryItem(text)
    M._deps.pasteboardSetContents(text)
    M._deps.keyStroke({"cmd"}, "v")
end

-- Build the dropdown menu
function M.buildMenu()
    local menu = {}

    -- Pomodoro section
    if M._state.pomodoroEndTime then
        local remaining = utils.getPomodoroSecondsRemaining(M._state.pomodoroEndTime, M._deps.getTime())
        local modeText = M._state.pomodoroMode == "work" and "Work" or "Break"
        table.insert(menu, {
            title = string.format("%s: %s", modeText, utils.formatPomodoroTime(remaining)),
            disabled = true,
        })
        table.insert(menu, {
            title = "Stop",
            fn = M.stopPomodoro,
        })
    else
        table.insert(menu, {
            title = "Start Work (25m)",
            fn = M.startPomodoroWork,
        })
        table.insert(menu, {
            title = "Start Break (5m)",
            fn = M.startPomodoroBreak,
        })
    end

    table.insert(menu, { title = "-" })
    table.insert(menu, { title = "Clipboard History", disabled = true })

    if #M._state.clipboardHistory > 0 then
        for i, text in ipairs(M._state.clipboardHistory) do
            local displayText = utils.truncateText(text, 40)
            table.insert(menu, {
                title = string.format("%d. %s", i, displayText),
                fn = function() M.pasteHistoryItem(text) end,
            })
        end
    else
        table.insert(menu, { title = "(empty)", disabled = true })
    end

    return menu
end

-- Create and return menubar
function M.create()
    M._state.menubar = hs.menubar.new()
    M._state.menubar:setTitle("\u{23F1}")
    M._state.menubar:setMenu(M.buildMenu)
    -- Keep extra reference to prevent GC
    M.menubar = M._state.menubar

    -- Start clipboard watcher
    M._state.clipboardWatcher = hs.pasteboard.watcher.new(function(text)
        pcall(M.onClipboardChange, text)
    end)
    M._state.clipboardWatcher:start()
    -- Keep extra reference to prevent GC
    M.clipboardWatcher = M._state.clipboardWatcher

    return M._state.menubar
end

-- Update title (called by refresh timer)
function M.refresh()
    if not M._state.menubar then return end

    local currTime = M._deps.getTime()

    if M._state.pomodoroEndTime then
        local remaining = utils.getPomodoroSecondsRemaining(M._state.pomodoroEndTime, currTime)
        if remaining > 0 then
            M._state.menubar:setTitle("\u{23F1}" .. utils.formatPomodoroTime(remaining))
            return utils.formatPomodoroTime(remaining)
        else
            -- Timer finished
            M.onPomodoroComplete()
        end
    end

    M._state.menubar:setTitle("\u{23F1}")
    return nil
end

-- Cleanup
function M.destroy()
    if M._state.menubar then
        M._state.menubar:delete()
        M._state.menubar = nil
    end
    if M._state.pomodoroTimer then
        M._state.pomodoroTimer:stop()
        M._state.pomodoroTimer = nil
    end
    if M._state.clipboardWatcher then
        M._state.clipboardWatcher:stop()
        M._state.clipboardWatcher = nil
    end
    M._state.pomodoroEndTime = nil
    M._state.pomodoroMode = nil
    M._state.clipboardHistory = {}
end

-- Reset for testing
function M.reset()
    M.destroy()
    M._deps = {
        getTime = function() return os.time() end,
        pasteboardSetContents = function(text) return hs.pasteboard.setContents(text) end,
        keyStroke = function(mods, key) return hs.eventtap.keyStroke(mods, key) end,
        notify = function(title, text)
            return hs.notify.new():title(title):informativeText(text):send()
        end,
    }
end

-- Getters for testing
function M.getClipboardHistory()
    return M._state.clipboardHistory
end

function M.getPomodoroMode()
    return M._state.pomodoroMode
end

function M.getPomodoroEndTime()
    return M._state.pomodoroEndTime
end

return M
