-- Battery Module Tests
-- Run with: busted tests/menubar/battery_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local battery = require("angus_scripts.menubar.battery")

describe("Battery Module", function()
    before_each(function()
        hs_mock.reset()
        battery.reset()
    end)

    describe("formatBattery", function()
        it("formats battery with hours and minutes remaining", function()
            local result = battery.formatBattery(87, 180)  -- 87%, 3 hours
            assert.are.equal("\u{1F50B}87% 3h0m", result)  -- 🔋87% 3h0m
        end)

        it("formats battery with only minutes remaining", function()
            local result = battery.formatBattery(95, 45)  -- 95%, 45 minutes
            assert.are.equal("\u{1F50B}95% 45m", result)  -- 🔋95% 45m
        end)

        it("formats battery without time remaining", function()
            local result = battery.formatBattery(50, nil)
            assert.are.equal("\u{1F50B}50%", result)  -- 🔋50%
        end)

        it("formats battery with zero time remaining", function()
            local result = battery.formatBattery(100, 0)
            assert.are.equal("\u{1F50B}100%", result)  -- 🔋100%
        end)

        it("shows lightning when below 20%", function()
            local result = battery.formatBattery(15, 30)
            assert.are.equal("\u{26A1}15% 30m", result)  -- ⚡15% 30m
        end)

        it("returns empty string for nil percentage", function()
            assert.are.equal("", battery.formatBattery(nil, 60))
        end)
    end)

    describe("toggleCaffeine", function()
        it("enables caffeine when off", function()
            battery._state.caffeineEnabled = false
            local setCalls = {}
            battery._deps.caffeinateSet = function(type, value)
                setCalls[type] = value
            end

            battery.toggleCaffeine()

            assert.is_true(battery._state.caffeineEnabled)
            assert.is_true(setCalls.displayIdle)
            assert.is_true(setCalls.systemIdle)
        end)

        it("disables caffeine when on", function()
            battery._state.caffeineEnabled = true
            local setCalls = {}
            battery._deps.caffeinateSet = function(type, value)
                setCalls[type] = value
            end

            battery.toggleCaffeine()

            assert.is_false(battery._state.caffeineEnabled)
            assert.is_false(setCalls.displayIdle)
            assert.is_false(setCalls.systemIdle)
        end)
    end)

    describe("create", function()
        it("creates menubar", function()
            battery.create()
            assert.is_not_nil(battery._state.menubar)
            local menubars = hs_mock.getMenubars()
            assert.are.equal(1, #menubars)
        end)

        it("sets initial title", function()
            battery.create()
            assert.are.equal("\u{1F50B}--%", battery._state.menubar:title())  -- 🔋--%
        end)
    end)

    describe("refresh", function()
        it("updates title with battery info", function()
            battery._deps.batteryPercentage = function() return 75 end
            battery._deps.batteryTimeRemaining = function() return 120 end

            battery.create()
            local display = battery.refresh()

            assert.are.equal("\u{1F50B}75% 2h0m", display)  -- 🔋75% 2h0m
            assert.are.equal("\u{1F50B}75% 2h0m", battery._state.menubar:title())  -- 🔋75% 2h0m
        end)
    end)

    describe("formatTime", function()
        it("formats hours and minutes", function()
            assert.are.equal("2h 30m", battery.formatTime(150))
        end)

        it("formats just minutes when less than an hour", function()
            assert.are.equal("45m", battery.formatTime(45))
        end)

        it("returns nil for nil input", function()
            assert.is_nil(battery.formatTime(nil))
        end)

        it("returns nil for negative input", function()
            assert.is_nil(battery.formatTime(-10))
        end)

        it("returns nil for zero input", function()
            assert.is_nil(battery.formatTime(0))
        end)
    end)

    describe("buildMenu", function()
        it("includes battery status header", function()
            battery._deps.batteryPercentage = function() return 75 end
            battery._deps.batteryIsCharging = function() return false end
            battery._deps.batteryIsCharged = function() return false end
            battery._deps.batteryHealth = function() return "Good" end
            battery._deps.batteryTimeRemaining = function() return 120 end
            battery._deps.batteryTimeToFullCharge = function() return -1 end

            battery.create()
            local menu = battery.buildMenu()

            assert.are.equal("Battery Status", menu[1].title)
        end)

        it("shows charge percentage", function()
            battery._deps.batteryPercentage = function() return 75 end
            battery._deps.batteryIsCharging = function() return false end
            battery._deps.batteryIsCharged = function() return false end
            battery._deps.batteryHealth = function() return "Good" end
            battery._deps.batteryTimeRemaining = function() return nil end
            battery._deps.batteryTimeToFullCharge = function() return nil end

            battery.create()
            local menu = battery.buildMenu()

            -- Find charge entry
            local foundCharge = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Charge: 75%%") then
                    foundCharge = true
                end
            end
            assert.is_true(foundCharge)
        end)

        it("shows charging status when charging", function()
            battery._deps.batteryPercentage = function() return 50 end
            battery._deps.batteryIsCharging = function() return true end
            battery._deps.batteryIsCharged = function() return false end
            battery._deps.batteryHealth = function() return "Good" end
            battery._deps.batteryTimeRemaining = function() return nil end
            battery._deps.batteryTimeToFullCharge = function() return 90 end

            battery.create()
            local menu = battery.buildMenu()

            -- Find charging entry
            local foundCharging = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Charging") and item.title:match("to full") then
                    foundCharging = true
                end
            end
            assert.is_true(foundCharging)
        end)

        it("shows fully charged status", function()
            battery._deps.batteryPercentage = function() return 100 end
            battery._deps.batteryIsCharging = function() return false end
            battery._deps.batteryIsCharged = function() return true end
            battery._deps.batteryHealth = function() return "Good" end
            battery._deps.batteryTimeRemaining = function() return nil end
            battery._deps.batteryTimeToFullCharge = function() return nil end

            battery.create()
            local menu = battery.buildMenu()

            -- Find fully charged entry
            local foundCharged = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Fully Charged") then
                    foundCharged = true
                end
            end
            assert.is_true(foundCharged)
        end)

        it("shows health", function()
            battery._deps.batteryPercentage = function() return 75 end
            battery._deps.batteryIsCharging = function() return false end
            battery._deps.batteryIsCharged = function() return false end
            battery._deps.batteryHealth = function() return "Good" end
            battery._deps.batteryTimeRemaining = function() return nil end
            battery._deps.batteryTimeToFullCharge = function() return nil end

            battery.create()
            local menu = battery.buildMenu()

            -- Find health entry
            local foundHealth = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Health: Good") then
                    foundHealth = true
                end
            end
            assert.is_true(foundHealth)
        end)

        it("includes caffeine toggle with clearer label", function()
            battery._state.caffeineEnabled = false
            battery._deps.batteryPercentage = function() return 75 end
            battery._deps.batteryIsCharging = function() return false end
            battery._deps.batteryIsCharged = function() return false end
            battery._deps.batteryHealth = function() return nil end
            battery._deps.batteryTimeRemaining = function() return nil end
            battery._deps.batteryTimeToFullCharge = function() return nil end

            battery.create()
            local menu = battery.buildMenu()

            -- Find caffeine entry
            local foundCaffeine = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Caffeine") then
                    foundCaffeine = true
                    assert.truthy(item.title:match("sleep allowed"))
                end
            end
            assert.is_true(foundCaffeine)
        end)

        it("shows ON status for caffeine", function()
            battery._state.caffeineEnabled = true
            battery._deps.batteryPercentage = function() return 75 end
            battery._deps.batteryIsCharging = function() return false end
            battery._deps.batteryIsCharged = function() return false end
            battery._deps.batteryHealth = function() return nil end
            battery._deps.batteryTimeRemaining = function() return nil end
            battery._deps.batteryTimeToFullCharge = function() return nil end

            battery.create()
            local menu = battery.buildMenu()

            -- Find caffeine entry
            local foundCaffeine = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Caffeine") then
                    foundCaffeine = true
                    assert.truthy(item.title:match("preventing sleep"))
                end
            end
            assert.is_true(foundCaffeine)
        end)
    end)

    describe("destroy", function()
        it("cleans up menubar and resets caffeine", function()
            battery.create()
            battery._state.caffeineEnabled = true
            battery.destroy()

            assert.is_nil(battery._state.menubar)
            assert.is_false(battery._state.caffeineEnabled)
        end)
    end)
end)
