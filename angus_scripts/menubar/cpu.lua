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

-- Build the dropdown menu showing top processes by CPU (grouped by app)
function M.buildMenu()
    -- Get more processes (50) to allow for grouping
    local output = M._deps.executeCommand("ps aux -r | tail -n +2 | head -n 50")
    local processes = utils.parsePsOutputWithCommand(output)
    local groups = utils.groupProcesses(processes, "cpu")

    local menu = {
        { title = "Top Apps by CPU", disabled = true },
        { title = "-" },
    }

    -- Show top 10 groups
    local groupCount = 0
    for _, g in ipairs(groups) do
        if groupCount >= 10 then break end
        groupCount = groupCount + 1

        if g.count == 1 then
            -- Single process - show directly
            local p = g.processes[1]
            table.insert(menu, {
                title = string.format("%-20s %5.1f%%", utils.truncateText(g.appName, 20), p.cpu),
                disabled = true,
            })
        else
            -- Multiple processes - show group header then children
            table.insert(menu, {
                title = string.format("%-14s %5.1f%% (%d)", utils.truncateText(g.appName, 14), g.totalCpu, g.count),
                disabled = true,
            })

            -- Show child processes with tree characters
            for i, p in ipairs(g.processes) do
                local prefix = (i == #g.processes) and "  └" or "  ├"
                table.insert(menu, {
                    title = string.format("%s PID %-8d %5.1f%%", prefix, p.pid, p.cpu),
                    disabled = true,
                })
            end
        end

        -- Add separator between groups (but not after the last one)
        if groupCount < 10 and groupCount < #groups then
            table.insert(menu, { title = "-" })
        end
    end

    if #groups == 0 then
        table.insert(menu, { title = "(no processes)", disabled = true })
    end

    return menu
end

-- Create and return menubar
function M.create()
    M._state.menubar = hs.menubar.new()
    M._state.menubar:setTitle("--")  -- Compact: no emoji (width bug on notch Macs)
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

    -- Compact: number with % (no emoji - width bug on notch Macs)
    M._state.menubar:setTitle(string.format("%d%%", cpu))

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
