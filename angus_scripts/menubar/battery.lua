-- Battery Menu Bar Module
-- Displays battery status and caffeine toggle on click

local M = {}

-- Injectable dependencies (for testing)
M._deps = {
    batteryPercentage = function() return hs.battery.percentage() end,
    batteryTimeRemaining = function() return hs.battery.timeRemaining() end,
    batteryIsCharging = function() return hs.battery.isCharging() end,
    batteryIsCharged = function() return hs.battery.isCharged() end,
    batteryHealth = function() return hs.battery.health() end,
    batteryTimeToFullCharge = function() return hs.battery.timeToFullCharge() end,
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

-- Format time as hours and minutes
function M.formatTime(minutes)
    if not minutes or minutes < 0 then
        return nil
    end
    local hours = math.floor(minutes / 60)
    local mins = minutes % 60
    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

-- Build the dropdown menu with battery status and caffeine toggle
function M.buildMenu()
    local menu = {
        { title = "Battery Status", disabled = true },
        { title = "-" },
    }

    -- Get battery info
    local pct = M._deps.batteryPercentage()
    local isCharging = M._deps.batteryIsCharging()
    local isCharged = M._deps.batteryIsCharged()
    local health = M._deps.batteryHealth()
    local timeRemaining = M._deps.batteryTimeRemaining()
    local timeToFull = M._deps.batteryTimeToFullCharge()

    -- Charge level
    if pct then
        table.insert(menu, {
            title = string.format("Charge: %d%%", pct),
            disabled = true,
        })
    end

    -- Charging status / time remaining
    if isCharged then
        table.insert(menu, {
            title = "Status: Fully Charged",
            disabled = true,
        })
    elseif isCharging then
        local timeStr = M.formatTime(timeToFull)
        if timeStr then
            table.insert(menu, {
                title = string.format("Charging: %s to full", timeStr),
                disabled = true,
            })
        else
            table.insert(menu, {
                title = "Charging...",
                disabled = true,
            })
        end
    else
        -- On battery
        local timeStr = M.formatTime(timeRemaining)
        if timeStr then
            table.insert(menu, {
                title = string.format("Time Remaining: %s", timeStr),
                disabled = true,
            })
        end
    end

    -- Health
    if health then
        table.insert(menu, {
            title = string.format("Health: %s", health),
            disabled = true,
        })
    end

    -- Separator before caffeine toggle
    table.insert(menu, { title = "-" })

    -- Caffeine toggle with clearer label
    local caffeineText = M._state.caffeineEnabled
        and "Caffeine: ON (preventing sleep)"
        or "Caffeine: OFF (sleep allowed)"
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
        batteryIsCharging = function() return hs.battery.isCharging() end,
        batteryIsCharged = function() return hs.battery.isCharged() end,
        batteryHealth = function() return hs.battery.health() end,
        batteryTimeToFullCharge = function() return hs.battery.timeToFullCharge() end,
        caffeinateSet = function(type, value) return hs.caffeinate.set(type, value) end,
    }
end

-- Getter for caffeine state (for testing)
function M.isCaffeineEnabled()
    return M._state.caffeineEnabled
end

return M
