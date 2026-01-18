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

-- Build the dropdown menu showing top processes by memory
function M.buildMenu()
    local output = M._deps.executeCommand("ps aux -m | tail -n +2 | head -n 10")
    local processes = utils.parsePsOutput(output)

    local menu = {
        { title = "Top Processes by Memory", disabled = true },
        { title = "-" },
    }

    for _, p in ipairs(processes) do
        -- RSS is in KB, convert to human readable
        local memStr = utils.formatBytes((p.rss or 0) * 1024)
        table.insert(menu, {
            title = string.format("%-18s %6s", utils.truncateText(p.name, 18), memStr),
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
