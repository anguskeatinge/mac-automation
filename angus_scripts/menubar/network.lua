-- Network Menu Bar Module
-- Displays network speeds and shows active connections on click

local M = {}
local utils = require("angus_scripts.menubar.utils")

-- Injectable dependencies (for testing)
M._deps = {
    executeCommand = function(cmd) return hs.execute(cmd) end,
    getTime = function() return os.time() end,
}

-- Constants
M.HISTORY_SIZE = 30  -- 30 samples × 2s = 60s rolling window

-- State specific to this module
M._state = {
    menubar = nil,
    prevNetBytes = nil,
    prevNetTime = nil,
    history = {},  -- Rolling history: {bytesIn, bytesOut, time}
}

-- Parse netstat -ib output to get bytes in/out for en0
function M.parseNetstat(output)
    if not output or output == "" then
        return nil
    end

    local bytesIn, bytesOut = 0, 0

    for line in output:gmatch("[^\n]+") do
        -- Look for en0 with Link# (the hardware interface line)
        if line:match("^en0%s") and line:match("<Link#") then
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

-- Format network speed as download/upload rates
function M.formatNetworkSpeed(bytesDelta, timeDelta)
    if not bytesDelta or timeDelta <= 0 then
        return "?", "?"
    end

    local bytesPerSecIn = bytesDelta.bytesIn / timeDelta
    local bytesPerSecOut = bytesDelta.bytesOut / timeDelta

    return utils.formatBytes(bytesPerSecIn), utils.formatBytes(bytesPerSecOut)
end

-- Calculate total bytes from history (last 1 minute)
function M.getHistoryTotals()
    local totalIn, totalOut = 0, 0
    for _, h in ipairs(M._state.history) do
        totalIn = totalIn + (h.bytesIn or 0)
        totalOut = totalOut + (h.bytesOut or 0)
    end
    return totalIn, totalOut
end

-- Add entry to rolling history
function M.addToHistory(bytesIn, bytesOut, time)
    table.insert(M._state.history, {
        bytesIn = bytesIn,
        bytesOut = bytesOut,
        time = time,
    })
    -- Trim to max size
    while #M._state.history > M.HISTORY_SIZE do
        table.remove(M._state.history, 1)
    end
end

-- Build the dropdown menu showing network-active processes
function M.buildMenu()
    local menu = {
        { title = "Network Stats", disabled = true },
        { title = "-" },
    }

    -- Add 1-minute totals if we have history
    local totalIn, totalOut = M.getHistoryTotals()
    if totalIn > 0 or totalOut > 0 then
        table.insert(menu, {
            title = string.format("Last 1 min: ↓%s ↑%s", utils.formatBytes(totalIn), utils.formatBytes(totalOut)),
            disabled = true,
        })
        table.insert(menu, { title = "-" })
    end

    -- Network active processes
    table.insert(menu, { title = "Network Active Processes", disabled = true })
    table.insert(menu, { title = "-" })

    -- nettop is fast (~13ms) and shows network activity per process
    local output = M._deps.executeCommand("nettop -P -l1 -n 2>/dev/null | tail -n +2 | head -n 10")
    local processes = utils.parseNettopOutput(output)

    for _, p in ipairs(processes) do
        local downStr = utils.formatBytes(p.bytesIn)
        local upStr = utils.formatBytes(p.bytesOut)
        table.insert(menu, {
            title = string.format("%-15s ↓%6s ↑%6s", utils.truncateText(p.name, 15), downStr, upStr),
            disabled = true,
        })
    end

    if #processes == 0 then
        table.insert(menu, { title = "(no network activity)", disabled = true })
    end

    return menu
end

-- Create and return menubar
function M.create()
    M._state.menubar = hs.menubar.new()
    M._state.menubar:setTitle("↓-- ↑--")
    M._state.menubar:setMenu(M.buildMenu)
    -- Keep extra reference to prevent GC
    M.menubar = M._state.menubar
    return M._state.menubar
end

-- Update title (called by refresh timer)
function M.refresh()
    if not M._state.menubar then return end

    local netstatOutput = M._deps.executeCommand("netstat -ib")
    local currNetBytes = M.parseNetstat(netstatOutput)
    local currTime = M._deps.getTime()

    local netDown, netUp = "--", "--"

    if currNetBytes and M._state.prevNetBytes and M._state.prevNetTime then
        local timeDelta = currTime - M._state.prevNetTime
        if timeDelta > 0 then
            local bytesDelta = {
                bytesIn = currNetBytes.bytesIn - M._state.prevNetBytes.bytesIn,
                bytesOut = currNetBytes.bytesOut - M._state.prevNetBytes.bytesOut,
            }
            netDown, netUp = M.formatNetworkSpeed(bytesDelta, timeDelta)

            -- Add to rolling history (only positive deltas)
            if bytesDelta.bytesIn >= 0 and bytesDelta.bytesOut >= 0 then
                M.addToHistory(bytesDelta.bytesIn, bytesDelta.bytesOut, currTime)
            end
        end
    end

    M._state.prevNetBytes = currNetBytes
    M._state.prevNetTime = currTime

    -- Arrow format: ↓down ↑up
    M._state.menubar:setTitle(string.format("↓%s ↑%s", netDown, netUp))

    return netDown, netUp
end

-- Cleanup
function M.destroy()
    if M._state.menubar then
        M._state.menubar:delete()
        M._state.menubar = nil
    end
    M._state.prevNetBytes = nil
    M._state.prevNetTime = nil
    M._state.history = {}
end

-- Reset for testing
function M.reset()
    M.destroy()
    M._state.history = {}
    M._deps = {
        executeCommand = function(cmd) return hs.execute(cmd) end,
        getTime = function() return os.time() end,
    }
end

return M
