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

-- Parse nettop output for network-active processes
-- Returns list of {name, bytesIn, bytesOut, pid}
function M.parseNettopOutput(output)
    if not output or output == "" then
        return {}
    end

    local processes = {}
    for line in output:gmatch("[^\n]+") do
        -- nettop format varies, but typically: process.pid, bytes_in, bytes_out
        -- Example: "Google Chrome.1234, 1024, 512"
        local name, pid, bytesIn, bytesOut = line:match("([^%.]+)%.(%d+),%s*(%d+),%s*(%d+)")
        if name and pid then
            table.insert(processes, {
                name = name,
                pid = tonumber(pid),
                bytesIn = tonumber(bytesIn) or 0,
                bytesOut = tonumber(bytesOut) or 0,
            })
        end
    end

    return processes
end

return M
