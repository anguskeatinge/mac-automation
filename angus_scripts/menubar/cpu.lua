-- CPU Menu Bar Module
-- Displays CPU usage and shows top processes on click

local M = {}
local utils = require("angus_scripts.menubar.utils")

-- Injectable dependencies (for testing)
M._deps = {
    executeCommand = function(cmd) return hs.execute(cmd) end,
    cpuUsageTicks = function() return hs.host.cpuUsageTicks() end,
}

-- State specific to this module
M._state = {
    menubar = nil,
    prevCpuTicks = nil,
}

-- Calculate CPU percentage from tick deltas
function M.calculateCpuPercent(prevTicks, currTicks)
    if not prevTicks or not currTicks then
        return 0
    end

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

-- Kill a process by PID
function M.killProcess(pid)
    M._deps.executeCommand(string.format("kill %d", pid))
    hs.alert.show("Killed process " .. pid)
end

-- Build the dropdown menu showing top processes by CPU
function M.buildMenu()
    local output = M._deps.executeCommand("ps aux -r | tail -n +2 | head -n 10")
    local processes = utils.parsePsOutput(output)

    local menu = {
        { title = "Top Processes by CPU", disabled = true },
        { title = "-" },
    }

    for _, p in ipairs(processes) do
        table.insert(menu, {
            title = string.format("%-18s %5.1f%%", utils.truncateText(p.name, 18), p.cpu),
            menu = {
                { title = string.format("Kill %s (PID %d)", p.name, p.pid), fn = function() M.killProcess(p.pid) end }
            }
        })
    end

    if #processes == 0 then
        table.insert(menu, { title = "(no processes)", disabled = true })
    end

    return menu
end

-- Create and return menubar
function M.create()
    M._state.menubar = hs.menubar.new()
    M._state.menubar:setTitle("⚙ --%")
    M._state.menubar:setMenu(M.buildMenu)
    -- Keep extra reference to prevent GC
    M.menubar = M._state.menubar

    -- Initialize CPU tick reading
    M._state.prevCpuTicks = M._deps.cpuUsageTicks()

    return M._state.menubar
end

-- Update title (called by refresh timer)
function M.refresh()
    if not M._state.menubar then return end

    local currTicks = M._deps.cpuUsageTicks()
    local cpu = M.calculateCpuPercent(M._state.prevCpuTicks, currTicks)
    M._state.prevCpuTicks = currTicks

    M._state.menubar:setTitle(string.format("⚙ %d%%", cpu))

    return cpu
end

-- Cleanup
function M.destroy()
    if M._state.menubar then
        M._state.menubar:delete()
        M._state.menubar = nil
    end
    M._state.prevCpuTicks = nil
end

-- Reset for testing
function M.reset()
    M.destroy()
    M._deps = {
        executeCommand = function(cmd) return hs.execute(cmd) end,
        cpuUsageTicks = function() return hs.host.cpuUsageTicks() end,
    }
end

return M
