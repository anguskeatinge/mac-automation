-- RAM Menu Bar Module
-- Displays RAM usage and shows top processes by memory on click

local M = {}
local utils = require("angus_scripts.menubar.utils")

-- Injectable dependencies (for testing)
M._deps = {
    executeCommand = function(cmd) return hs.execute(cmd) end,
    vmStat = function() return hs.host.vmStat() end,
}

-- State specific to this module
M._state = {
    menubar = nil,
}

-- Format RAM usage from vmStat
function M.formatRam(vmStats, pageSize)
    if not vmStats then return "?" end
    pageSize = pageSize or vmStats.pageSize or 4096

    local usedPages = (vmStats.pagesWiredDown or 0) + (vmStats.pagesActive or 0)
    local usedBytes = usedPages * pageSize

    return utils.formatBytes(usedBytes)
end

-- Kill a process by PID
function M.killProcess(pid)
    M._deps.executeCommand(string.format("kill %d", pid))
    hs.alert.show("Killed process " .. pid)
end

-- Build the dropdown menu showing top processes by memory (grouped by app)
function M.buildMenu()
    -- Get more processes (50) to allow for grouping
    local output = M._deps.executeCommand("ps aux -m | tail -n +2 | head -n 50")
    local processes = utils.parsePsOutputWithCommand(output)
    local groups = utils.groupProcesses(processes, "rss")

    local menu = {
        { title = "Top Apps by Memory", disabled = true },
        { title = "-" },
    }

    -- Show top 10 groups
    local groupCount = 0
    for _, g in ipairs(groups) do
        if groupCount >= 10 then break end
        groupCount = groupCount + 1

        local totalMemStr = utils.formatBytes((g.totalRss or 0) * 1024)

        if g.count == 1 then
            -- Single process - show directly with kill option
            local p = g.processes[1]
            table.insert(menu, {
                title = string.format("%-20s %6s", utils.truncateText(g.appName, 20), totalMemStr),
                menu = {
                    { title = string.format("Kill PID %d", p.pid), fn = function() M.killProcess(p.pid) end }
                }
            })
        else
            -- Multiple processes - show group header then children
            table.insert(menu, {
                title = string.format("%-16s %6s (%d)", utils.truncateText(g.appName, 16), totalMemStr, g.count),
                disabled = true,
            })

            -- Show child processes with tree characters
            for i, p in ipairs(g.processes) do
                local prefix = (i == #g.processes) and "  └" or "  ├"
                local memStr = utils.formatBytes((p.rss or 0) * 1024)
                table.insert(menu, {
                    title = string.format("%s PID %-8d %6s", prefix, p.pid, memStr),
                    menu = {
                        { title = string.format("Kill PID %d", p.pid), fn = function() M.killProcess(p.pid) end }
                    }
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
    M._state.menubar:setTitle("▦ --")
    M._state.menubar:setMenu(M.buildMenu)
    -- Keep extra reference to prevent GC
    M.menubar = M._state.menubar
    return M._state.menubar
end

-- Update title (called by refresh timer)
function M.refresh()
    if not M._state.menubar then
        print("[ram] menubar is nil!")
        return
    end

    local vmStats = M._deps.vmStat()
    if not vmStats then
        print("[ram] vmStat returned nil")
        return
    end

    local ram = M.formatRam(vmStats)

    M._state.menubar:setTitle(string.format("▦ %s", ram))

    return ram
end

-- Cleanup
function M.destroy()
    if M._state.menubar then
        M._state.menubar:delete()
        M._state.menubar = nil
    end
end

-- Reset for testing
function M.reset()
    M.destroy()
    M._deps = {
        executeCommand = function(cmd) return hs.execute(cmd) end,
        vmStat = function() return hs.host.vmStat() end,
    }
end

return M
