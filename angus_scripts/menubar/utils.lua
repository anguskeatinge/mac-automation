-- Shared utility functions for menubar modules

local M = {}

-- Format bytes to human readable string (e.g., "1.5G", "256M", "512K")
function M.formatBytes(bytes)
    if not bytes or bytes < 0 then
        return "0B"
    end
    bytes = math.floor(bytes)
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

-- Truncate text for display
function M.truncateText(text, maxLen)
    maxLen = maxLen or 40
    if not text then return "" end
    if #text <= maxLen then return text end
    return text:sub(1, maxLen - 3) .. "..."
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

-- Parse ps output for process list (works for both CPU and RAM sorting)
-- Returns list of {name, cpu, mem, pid}
function M.parsePsOutput(output)
    if not output or output == "" then
        return {}
    end

    local processes = {}
    local lineNum = 0
    for line in output:gmatch("[^\n]+") do
        lineNum = lineNum + 1
        -- ps aux format: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
        -- Fields are whitespace-separated
        local fields = {}
        for field in line:gmatch("%S+") do
            table.insert(fields, field)
        end

        if #fields >= 11 then
            local pid = tonumber(fields[2])
            local cpu = tonumber(fields[3])
            local mem = tonumber(fields[4])
            local rss = tonumber(fields[6])  -- RSS in KB
            -- Command is everything from field 11 onwards
            local command = fields[11]
            -- Get the base command name (strip path)
            local name = command:match("([^/]+)$") or command

            if pid and cpu and mem then
                table.insert(processes, {
                    name = name,
                    cpu = cpu,
                    mem = mem,
                    rss = rss,
                    pid = pid,
                })
            end
        end
    end

    return processes
end

-- Parse human-readable byte string to number (e.g., "35 KiB" → 35840)
function M.parseHumanBytes(str)
    if not str or str == "" then return 0 end

    -- Remove leading/trailing whitespace
    str = str:match("^%s*(.-)%s*$")

    -- Match number and optional unit
    local num, unit = str:match("^([%d%.]+)%s*(%a*)")
    num = tonumber(num)
    if not num then return 0 end

    unit = unit and unit:lower() or ""

    -- Handle various unit formats (KiB, KB, K, etc.)
    if unit:match("^g") then
        return math.floor(num * 1073741824)  -- GiB/GB
    elseif unit:match("^m") then
        return math.floor(num * 1048576)      -- MiB/MB
    elseif unit:match("^k") then
        return math.floor(num * 1024)         -- KiB/KB
    elseif unit:match("^b") or unit == "" then
        return math.floor(num)                -- Bytes
    end

    return math.floor(num)
end

-- Parse nettop output for network-active processes
-- Returns list of {name, bytesIn, bytesOut, pid}
-- nettop -P -l1 -n format (whitespace-separated):
-- time      process.PID  bytes_in  bytes_out
-- 22:52:13  syslogd.354    0 B     35 KiB
function M.parseNettopOutput(output)
    if not output or output == "" then
        return {}
    end

    local processes = {}
    for line in output:gmatch("[^\n]+") do
        -- Try CSV format first (for backwards compatibility): "Name.PID, bytesIn, bytesOut"
        local name, pid, bytesIn, bytesOut = line:match("([^%.]+)%.(%d+),%s*(%d+),%s*(%d+)")
        if name and pid then
            table.insert(processes, {
                name = name,
                pid = tonumber(pid),
                bytesIn = tonumber(bytesIn) or 0,
                bytesOut = tonumber(bytesOut) or 0,
            })
        else
            -- Parse actual nettop -n output format (whitespace-separated with human bytes)
            -- Format: "time  process.PID  bytesIn  bytesOut" where bytes can be "35 KiB"
            -- Example: "22:52:13 syslogd.354     0 B     35 KiB"
            -- Split by multiple spaces to separate columns
            local parts = {}
            for part in line:gmatch("%S+") do
                table.insert(parts, part)
            end

            -- We need at least: time, name.pid, bytes_in_num, bytes_in_unit, bytes_out_num, bytes_out_unit
            -- But units might be missing (just a number) or combined
            if #parts >= 4 then
                local namePid = parts[2]
                if namePid then
                    name, pid = namePid:match("([^%.]+)%.(%d+)")
                    if name and pid then
                        -- Reconstruct bytes fields - they might be "35 KiB" or just "35"
                        local bytesInStr = ""
                        local bytesOutStr = ""

                        if #parts == 4 then
                            -- Just numbers: time name.pid bytesIn bytesOut
                            bytesInStr = parts[3]
                            bytesOutStr = parts[4]
                        elseif #parts == 5 then
                            -- One has unit: time name.pid bytesIn bytesInUnit bytesOut
                            -- Or: time name.pid bytesIn bytesOut bytesOutUnit
                            if parts[4]:match("%a") then
                                bytesInStr = parts[3] .. " " .. parts[4]
                                bytesOutStr = parts[5]
                            else
                                bytesInStr = parts[3]
                                bytesOutStr = parts[4] .. " " .. parts[5]
                            end
                        elseif #parts >= 6 then
                            -- Both have units: time name.pid bytesIn bytesInUnit bytesOut bytesOutUnit
                            bytesInStr = parts[3] .. " " .. parts[4]
                            bytesOutStr = parts[5] .. " " .. parts[6]
                        end

                        table.insert(processes, {
                            name = name,
                            pid = tonumber(pid),
                            bytesIn = M.parseHumanBytes(bytesInStr),
                            bytesOut = M.parseHumanBytes(bytesOutStr),
                        })
                    end
                end
            end
        end
    end

    return processes
end

-- Extract app name from command path
-- Examples:
-- "/Applications/Visual Studio Code.app/Contents/MacOS/Code" → "Visual Studio Code"
-- "/usr/bin/python3" → "python3"
-- "Google Chrome Helper" → "Google Chrome Helper"
function M.extractAppName(command)
    if not command or command == "" then
        return "Unknown"
    end

    -- Look for .app bundle in path
    local appName = command:match("/([^/]+)%.app/")
    if appName then
        return appName
    end

    -- Fall back to last path component
    local baseName = command:match("([^/]+)$")
    return baseName or command
end

-- Parse ps output and extract full command path for app name resolution
-- Returns list of {name, appName, cpu, mem, rss, pid, command}
function M.parsePsOutputWithCommand(output)
    if not output or output == "" then
        return {}
    end

    local processes = {}
    for line in output:gmatch("[^\n]+") do
        -- ps aux format: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND...
        local fields = {}
        for field in line:gmatch("%S+") do
            table.insert(fields, field)
        end

        if #fields >= 11 then
            local pid = tonumber(fields[2])
            local cpu = tonumber(fields[3])
            local mem = tonumber(fields[4])
            local rss = tonumber(fields[6])  -- RSS in KB

            -- Command is everything from field 11 onwards (may have spaces)
            local command = table.concat(fields, " ", 11)

            -- For app name extraction, use the full command which includes spaces
            local appName = M.extractAppName(command)

            -- Base name: get executable name from command
            -- For paths like "/Applications/App.app/Contents/MacOS/Executable", get "Executable"
            local baseName
            if command:sub(1, 1) == "/" then
                -- It's an absolute path - get last component
                -- Find the last / and take everything after it (up to any space/argument)
                local lastSlashPos = 0
                for i = 1, #command do
                    if command:sub(i, i) == "/" then
                        lastSlashPos = i
                    end
                end
                if lastSlashPos > 0 and lastSlashPos < #command then
                    baseName = command:sub(lastSlashPos + 1)
                    -- Take only the first word if there are arguments
                    baseName = baseName:match("^(%S+)") or baseName
                else
                    baseName = command:match("([^/]+)$") or command
                end
            else
                -- Not an absolute path - take first word
                baseName = command:match("^(%S+)") or command
            end

            if pid and cpu and mem then
                table.insert(processes, {
                    name = baseName,
                    appName = appName,
                    cpu = cpu,
                    mem = mem,
                    rss = rss,
                    pid = pid,
                    command = command,
                })
            end
        end
    end

    return processes
end

-- Group processes by app name
-- Returns list of groups: {appName, totalCpu, totalRss, count, processes}
-- Each process in the group: {pid, cpu, rss, name}
function M.groupProcesses(processes, sortBy)
    if not processes or #processes == 0 then
        return {}
    end

    sortBy = sortBy or "rss"  -- "rss" for RAM, "cpu" for CPU

    -- Group by app name
    local groups = {}
    local groupIndex = {}

    for _, p in ipairs(processes) do
        local appName = p.appName or p.name
        if not groupIndex[appName] then
            groupIndex[appName] = #groups + 1
            groups[#groups + 1] = {
                appName = appName,
                totalCpu = 0,
                totalRss = 0,
                count = 0,
                processes = {},
            }
        end

        local g = groups[groupIndex[appName]]
        g.totalCpu = g.totalCpu + (p.cpu or 0)
        g.totalRss = g.totalRss + (p.rss or 0)
        g.count = g.count + 1
        table.insert(g.processes, {
            pid = p.pid,
            cpu = p.cpu or 0,
            rss = p.rss or 0,
            name = p.name,
        })
    end

    -- Sort processes within each group
    for _, g in ipairs(groups) do
        if sortBy == "cpu" then
            table.sort(g.processes, function(a, b) return a.cpu > b.cpu end)
        else
            table.sort(g.processes, function(a, b) return a.rss > b.rss end)
        end
    end

    -- Sort groups by total
    if sortBy == "cpu" then
        table.sort(groups, function(a, b) return a.totalCpu > b.totalCpu end)
    else
        table.sort(groups, function(a, b) return a.totalRss > b.totalRss end)
    end

    return groups
end

return M
