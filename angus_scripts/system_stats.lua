-- System Stats Menu Bar
-- Displays CPU, RAM, Network, Battery, and Disk stats in the menu bar
-- Includes Caffeine toggle, Pomodoro timer, and Clipboard history

local M = {}

------------------------------------------------------
-- Injectable Dependencies (for testing)
------------------------------------------------------

M._deps = {
    executeCommand = function(cmd) return hs.execute(cmd) end,
    getTime = function() return os.time() end,
}

------------------------------------------------------
-- State (resettable for tests)
------------------------------------------------------

local function getDefaultState()
    return {
        -- Separate menubar items
        cpuMenubar = nil,
        ramMenubar = nil,
        netMenubar = nil,
        batteryMenubar = nil,
        pomodoroMenubar = nil,
        -- Timers and watchers
        refreshTimer = nil,
        pomodoroTimer = nil,
        clipboardWatcher = nil,
        -- Feature state
        caffeineEnabled = false,
        pomodoroEndTime = nil,
        pomodoroMode = nil,  -- "work" or "break"
        clipboardHistory = {},
        -- Previous readings for delta calculations
        prevCpuTicks = nil,
        prevNetBytes = nil,
        prevNetTime = nil,
    }
end

M._state = getDefaultState()

function M.reset()
    -- Stop any running timers/watchers
    if M._state.refreshTimer then M._state.refreshTimer:stop() end
    if M._state.pomodoroTimer then M._state.pomodoroTimer:stop() end
    if M._state.clipboardWatcher then M._state.clipboardWatcher:stop() end

    -- Delete all menubars
    if M._state.cpuMenubar then M._state.cpuMenubar:delete() end
    if M._state.ramMenubar then M._state.ramMenubar:delete() end
    if M._state.netMenubar then M._state.netMenubar:delete() end
    if M._state.batteryMenubar then M._state.batteryMenubar:delete() end
    if M._state.pomodoroMenubar then M._state.pomodoroMenubar:delete() end

    M._state = getDefaultState()
end

------------------------------------------------------
-- PURE FUNCTIONS (easily testable)
------------------------------------------------------

-- Format bytes to human readable string (e.g., "1.5G", "256M", "512K")
function M.formatBytes(bytes)
    if not bytes or bytes < 0 then
        return "0B"
    end
    bytes = math.floor(bytes)  -- Ensure integer
    if bytes >= 1073741824 then  -- 1 GB
        return string.format("%.1fG", bytes / 1073741824)
    elseif bytes >= 1048576 then  -- 1 MB
        return string.format("%.0fM", bytes / 1048576)
    elseif bytes >= 1024 then  -- 1 KB
        return string.format("%.0fK", bytes / 1024)
    else
        return string.format("%dB", bytes)
    end
end

-- Calculate CPU percentage from tick deltas
-- Ticks table has .overall with: user, system, nice, idle, active
function M.calculateCpuPercent(prevTicks, currTicks)
    if not prevTicks or not currTicks then
        return 0
    end

    -- Extract the overall stats (combined across all cores)
    local prev = prevTicks.overall or prevTicks
    local curr = currTicks.overall or currTicks

    if not prev.user or not curr.user then
        return 0
    end

    local prevTotal = prev.user + prev.system + prev.nice + prev.idle
    local currTotal = curr.user + curr.system + curr.nice + curr.idle
    local totalDelta = currTotal - prevTotal

    if totalDelta == 0 then
        return 0
    end

    local idleDelta = curr.idle - prev.idle
    local usedDelta = totalDelta - idleDelta

    return math.floor((usedDelta / totalDelta) * 100 + 0.5)
end

-- Format RAM usage from vmStat
-- vmStat has: pageSize, pagesWiredDown, pagesActive, pagesInactive, pagesFree
function M.formatRam(vmStats, pageSize)
    if not vmStats then return "?" end
    pageSize = pageSize or vmStats.pageSize or 4096

    local usedPages = (vmStats.pagesWiredDown or 0) + (vmStats.pagesActive or 0)
    local usedBytes = usedPages * pageSize

    return M.formatBytes(usedBytes)
end

-- Format network speed as download/upload rates
function M.formatNetworkSpeed(bytesDelta, timeDelta)
    if not bytesDelta or timeDelta <= 0 then
        return "?", "?"
    end

    local bytesPerSecIn = bytesDelta.bytesIn / timeDelta
    local bytesPerSecOut = bytesDelta.bytesOut / timeDelta

    return M.formatBytes(bytesPerSecIn), M.formatBytes(bytesPerSecOut)
end

-- Parse netstat -ib output to get bytes in/out for en0
function M.parseNetstat(output)
    if not output or output == "" then
        return nil
    end

    local bytesIn, bytesOut = 0, 0

    for line in output:gmatch("[^\n]+") do
        -- Look for en0 with Link# (the hardware interface line)
        if line:match("^en0%s") and line:match("<Link#") then
            -- Parse the columns: Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
            local fields = {}
            for field in line:gmatch("%S+") do
                table.insert(fields, field)
            end
            -- Ibytes is typically column 7, Obytes is column 10
            if #fields >= 10 then
                bytesIn = tonumber(fields[7]) or 0
                bytesOut = tonumber(fields[10]) or 0
            end
            break
        end
    end

    return { bytesIn = bytesIn, bytesOut = bytesOut }
end

-- Format battery display string
function M.formatBattery(pct, timeRemaining)
    if not pct then return "" end

    local icon = pct > 20 and "" or ""

    if timeRemaining and timeRemaining > 0 then
        local hours = math.floor(timeRemaining / 60)
        local mins = timeRemaining % 60
        if hours > 0 then
            return string.format("%s %d%% %dh%dm", icon, pct, hours, mins)
        else
            return string.format("%s %d%% %dm", icon, pct, mins)
        end
    else
        return string.format("%s %d%%", icon, pct)
    end
end

-- Format pomodoro time as MM:SS
function M.formatPomodoroTime(secondsRemaining)
    if not secondsRemaining or secondsRemaining < 0 then
        return "00:00"
    end
    local mins = math.floor(secondsRemaining / 60)
    local secs = secondsRemaining % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Calculate pomodoro seconds remaining
function M.getPomodoroSecondsRemaining(endTime, currentTime)
    if not endTime or not currentTime then return 0 end
    local remaining = endTime - currentTime
    return remaining > 0 and remaining or 0
end

-- Add item to clipboard history (most recent first)
function M.addToClipboardHistory(text, history, maxItems)
    if not text or text == "" then return history end
    maxItems = maxItems or 10

    -- Remove if already exists (to move to front)
    for i = #history, 1, -1 do
        if history[i] == text then
            table.remove(history, i)
        end
    end

    -- Add to front
    table.insert(history, 1, text)

    -- Trim to max
    while #history > maxItems do
        table.remove(history)
    end

    return history
end

-- Truncate text for display
function M.truncateText(text, maxLen)
    maxLen = maxLen or 40
    if not text then return "" end
    if #text <= maxLen then return text end
    return text:sub(1, maxLen - 3) .. "..."
end

-- Build menu bar title from collected stats
function M.buildMenuBarTitle(stats)
    local parts = {}

    -- Shorter format to fit in menu bar
    if stats.cpu then
        table.insert(parts, string.format("%d%%", stats.cpu))
    end

    if stats.ram then
        table.insert(parts, stats.ram)
    end

    if stats.pomodoro then
        table.insert(parts, stats.pomodoro)
    end

    -- Start with icon so it's always visible
    return "📊" .. table.concat(parts, " ")
end

------------------------------------------------------
-- SIDE-EFFECT FUNCTIONS
------------------------------------------------------

-- Collect all current stats
function M.collectStats()
    local stats = {}

    -- CPU
    local currTicks = hs.host.cpuUsageTicks()
    stats.cpu = M.calculateCpuPercent(M._state.prevCpuTicks, currTicks)
    M._state.prevCpuTicks = currTicks

    -- RAM
    local vmStats = hs.host.vmStat()
    stats.ram = M.formatRam(vmStats)

    -- Network
    local netstatOutput = M._deps.executeCommand("netstat -ib")
    local currNetBytes = M.parseNetstat(netstatOutput)
    local currTime = M._deps.getTime()

    if currNetBytes and M._state.prevNetBytes and M._state.prevNetTime then
        local timeDelta = currTime - M._state.prevNetTime
        if timeDelta > 0 then
            local bytesDelta = {
                bytesIn = currNetBytes.bytesIn - M._state.prevNetBytes.bytesIn,
                bytesOut = currNetBytes.bytesOut - M._state.prevNetBytes.bytesOut,
            }
            stats.netDown, stats.netUp = M.formatNetworkSpeed(bytesDelta, timeDelta)
        end
    end
    M._state.prevNetBytes = currNetBytes
    M._state.prevNetTime = currTime

    -- Battery
    local batteryPct = hs.battery.percentage()
    local batteryTime = hs.battery.timeRemaining()
    if batteryPct then
        stats.battery = M.formatBattery(batteryPct, batteryTime)
    end

    -- Disk
    local volumes = hs.fs.volume.allVolumes()
    if volumes and volumes["/"] then
        local rootVol = volumes["/"]
        local freeBytes = rootVol.NSURLVolumeAvailableCapacityKey
        if freeBytes then
            stats.disk = M.formatBytes(freeBytes)
        end
    end

    -- Pomodoro
    if M._state.pomodoroEndTime then
        local remaining = M.getPomodoroSecondsRemaining(M._state.pomodoroEndTime, currTime)
        if remaining > 0 then
            stats.pomodoro = M.formatPomodoroTime(remaining)
        else
            -- Timer finished
            M.onPomodoroComplete()
        end
    end

    return stats
end

-- Handle pomodoro completion
function M.onPomodoroComplete()
    local message
    if M._state.pomodoroMode == "work" then
        message = "Work session complete! Time for a break."
    else
        message = "Break over! Ready to work?"
    end

    hs.notify.new():title("Pomodoro"):informativeText(message):send()

    M._state.pomodoroEndTime = nil
    M._state.pomodoroMode = nil
    if M._state.pomodoroTimer then
        M._state.pomodoroTimer:stop()
        M._state.pomodoroTimer = nil
    end
end

-- Toggle caffeine (prevent sleep)
function M.toggleCaffeine()
    M._state.caffeineEnabled = not M._state.caffeineEnabled
    hs.caffeinate.set("displayIdle", M._state.caffeineEnabled)
    hs.caffeinate.set("systemIdle", M._state.caffeineEnabled)
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
    M.addToClipboardHistory(text, M._state.clipboardHistory, 10)
end

-- Paste item from clipboard history
function M.pasteHistoryItem(text)
    hs.pasteboard.setContents(text)
    hs.eventtap.keyStroke({"cmd"}, "v")
end

-- Build dropdown menu
function M.buildMenu()
    local menu = {}

    -- Caffeine toggle
    local caffeineIcon = M._state.caffeineEnabled and "☕" or "😴"
    local caffeineText = M._state.caffeineEnabled and "Caffeine: ON (awake)" or "Caffeine: OFF (sleep allowed)"
    table.insert(menu, {
        title = string.format("%s %s", caffeineIcon, caffeineText),
        fn = M.toggleCaffeine,
    })

    table.insert(menu, { title = "-" })

    -- Pomodoro section
    table.insert(menu, { title = "Pomodoro", disabled = true })

    if M._state.pomodoroEndTime then
        local remaining = M.getPomodoroSecondsRemaining(M._state.pomodoroEndTime, M._deps.getTime())
        local modeText = M._state.pomodoroMode == "work" and "Work" or "Break"
        table.insert(menu, {
            title = string.format("   %s: %s remaining", modeText, M.formatPomodoroTime(remaining)),
            disabled = true,
        })
        table.insert(menu, {
            title = "   Stop Timer",
            fn = M.stopPomodoro,
        })
    else
        table.insert(menu, {
            title = "    Start Work (25min)",
            fn = M.startPomodoroWork,
        })
        table.insert(menu, {
            title = "    Start Break (5min)",
            fn = M.startPomodoroBreak,
        })
    end

    table.insert(menu, { title = "-" })

    -- Clipboard history section
    table.insert(menu, { title = "Clipboard History", disabled = true })
    if #M._state.clipboardHistory > 0 then
        for i, text in ipairs(M._state.clipboardHistory) do
            local displayText = M.truncateText(text, 50)
            table.insert(menu, {
                title = string.format("   %d. %s", i, displayText),
                fn = function() M.pasteHistoryItem(text) end,
            })
        end
    else
        table.insert(menu, { title = "   (empty)", disabled = true })
    end

    return menu
end

-- Refresh menu bar display
function M.refresh()
    local ok, stats = pcall(M.collectStats)
    if not ok then
        -- print("[system_stats] ERROR collecting stats: " .. tostring(stats))
        return
    end

    -- Update CPU menubar
    if M._state.cpuMenubar and stats.cpu then
        M._state.cpuMenubar:setTitle(string.format("CPU:%d%%", stats.cpu))
    end

    -- Update RAM menubar
    if M._state.ramMenubar and stats.ram then
        M._state.ramMenubar:setTitle(string.format("RAM:%s", stats.ram))
    end

    -- Update Network menubar
    if M._state.netMenubar then
        if stats.netDown and stats.netUp then
            M._state.netMenubar:setTitle(string.format("↓%s ↑%s", stats.netDown, stats.netUp))
        else
            M._state.netMenubar:setTitle("↓-- ↑--")
        end
    end

    -- Update Battery menubar
    if M._state.batteryMenubar and stats.battery then
        M._state.batteryMenubar:setTitle(stats.battery)
    end

    -- Update Pomodoro menubar (only show when active or as control)
    if M._state.pomodoroMenubar then
        if stats.pomodoro then
            M._state.pomodoroMenubar:setTitle("🍅" .. stats.pomodoro)
        else
            M._state.pomodoroMenubar:setTitle("🍅")
        end
    end
end

-- Build battery dropdown menu (with caffeine toggle)
function M.buildBatteryMenu()
    local menu = {}

    local caffeineIcon = M._state.caffeineEnabled and "☕" or "😴"
    local caffeineText = M._state.caffeineEnabled and "Caffeine ON" or "Caffeine OFF"
    table.insert(menu, {
        title = string.format("%s %s", caffeineIcon, caffeineText),
        fn = M.toggleCaffeine,
    })

    return menu
end

-- Build pomodoro dropdown menu
function M.buildPomodoroMenu()
    local menu = {}

    if M._state.pomodoroEndTime then
        local remaining = M.getPomodoroSecondsRemaining(M._state.pomodoroEndTime, M._deps.getTime())
        local modeText = M._state.pomodoroMode == "work" and "Work" or "Break"
        table.insert(menu, {
            title = string.format("%s: %s", modeText, M.formatPomodoroTime(remaining)),
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
            local displayText = M.truncateText(text, 40)
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

-- Start the system stats menu bar
function M.start()
    -- print("[system_stats] Starting...")

    -- Clean up any existing menubars first
    M.reset()

    -- Create separate menubar items (rightmost first, so order is: CPU RAM Net Battery Pomodoro)
    M._state.pomodoroMenubar = hs.menubar.new()
    M._state.batteryMenubar = hs.menubar.new()
    M._state.netMenubar = hs.menubar.new()
    M._state.ramMenubar = hs.menubar.new()
    M._state.cpuMenubar = hs.menubar.new()

    -- Store on M to prevent garbage collection
    M.cpuMenubar = M._state.cpuMenubar
    M.ramMenubar = M._state.ramMenubar
    M.netMenubar = M._state.netMenubar
    M.batteryMenubar = M._state.batteryMenubar
    M.pomodoroMenubar = M._state.pomodoroMenubar

    -- Set menus once (callbacks will fetch fresh data when clicked)
    M._state.batteryMenubar:setMenu(M.buildBatteryMenu)
    M._state.pomodoroMenubar:setMenu(M.buildPomodoroMenu)

    -- print("[system_stats] Menubars created")

    -- Initial CPU tick reading (needed for delta calculation)
    M._state.prevCpuTicks = hs.host.cpuUsageTicks()

    -- Start refresh timer (every 2 seconds)
    M.refreshTimer = hs.timer.doEvery(2, function()
        local ok, err = pcall(M.refresh)
        if not ok then
            -- print("[system_stats] Timer error: " .. tostring(err))
        end
    end)
    M._state.refreshTimer = M.refreshTimer

    -- Start clipboard watcher
    M.clipboardWatcher = hs.pasteboard.watcher.new(function(text)
        pcall(M.onClipboardChange, text)
    end)
    M.clipboardWatcher:start()
    M._state.clipboardWatcher = M.clipboardWatcher

    -- Initial refresh
    M.refresh()
    -- print("[system_stats] Started")
end

-- Stop the system stats menu bar
function M.stop()
    M.reset()
end

return M
