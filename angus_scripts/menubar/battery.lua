-- Battery Menu Bar Module
-- Displays battery status and caffeine toggle on click

local M = {}

-- Injectable dependencies (for testing)
M._deps = {
    batteryPercentage = function() return hs.battery.percentage() end,
    batteryTimeRemaining = function() return hs.battery.timeRemaining() end,
    caffeinateSet = function(type, value) return hs.caffeinate.set(type, value) end,
}

-- State specific to this module
M._state = {
    menubar = nil,
    caffeineEnabled = false,
}

-- Format battery display string
function M.formatBattery(pct, timeRemaining)
    if not pct then return "" end

    -- Use emoji battery indicator
    local icon = pct > 20 and "\u{1F50B}" or "\u{26A1}"  -- 🔋 or ⚡

    if timeRemaining and timeRemaining > 0 then
        local hours = math.floor(timeRemaining / 60)
        local mins = timeRemaining % 60
        if hours > 0 then
            return string.format("%s%d%% %dh%dm", icon, pct, hours, mins)
        else
            return string.format("%s%d%% %dm", icon, pct, mins)
        end
    else
        return string.format("%s%d%%", icon, pct)
    end
end

-- Toggle caffeine (prevent sleep)
function M.toggleCaffeine()
    M._state.caffeineEnabled = not M._state.caffeineEnabled
    M._deps.caffeinateSet("displayIdle", M._state.caffeineEnabled)
    M._deps.caffeinateSet("systemIdle", M._state.caffeineEnabled)
end

-- Build the dropdown menu with caffeine toggle
function M.buildMenu()
    local menu = {}

    local caffeineText = M._state.caffeineEnabled and "[ON] Caffeine (awake)" or "[OFF] Caffeine (sleep allowed)"
    table.insert(menu, {
        title = caffeineText,
        fn = M.toggleCaffeine,
    })

    return menu
end

-- Create and return menubar
function M.create()
    M._state.menubar = hs.menubar.new()
    M._state.menubar:setTitle("\u{1F50B}--%")  -- 🔋
    M._state.menubar:setMenu(M.buildMenu)
    -- Keep extra reference to prevent GC
    M.menubar = M._state.menubar
    return M._state.menubar
end

-- Update title (called by refresh timer)
function M.refresh()
    if not M._state.menubar then return end

    local batteryPct = M._deps.batteryPercentage()
    local batteryTime = M._deps.batteryTimeRemaining()

    if batteryPct then
        local display = M.formatBattery(batteryPct, batteryTime)
        M._state.menubar:setTitle(display)
        return display
    end

    return nil
end

-- Cleanup
function M.destroy()
    if M._state.menubar then
        M._state.menubar:delete()
        M._state.menubar = nil
    end
    M._state.caffeineEnabled = false
end

-- Reset for testing
function M.reset()
    M.destroy()
    M._deps = {
        batteryPercentage = function() return hs.battery.percentage() end,
        batteryTimeRemaining = function() return hs.battery.timeRemaining() end,
        caffeinateSet = function(type, value) return hs.caffeinate.set(type, value) end,
    }
end

-- Getter for caffeine state (for testing)
function M.isCaffeineEnabled()
    return M._state.caffeineEnabled
end

return M
