-- System Stats Tests
-- Run with: busted tests/system_stats_spec.lua

-- Set up package path to find our modules
package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

-- Load the mock before loading system_stats (so it gets the mock `hs`)
local hs_mock = require("tests.mocks.hs_mock")

-- Make hs_mock available as global `hs` before requiring system_stats
_G.hs = hs_mock

-- Now load the system stats module
local stats = require("angus_scripts.system_stats")

describe("System Stats", function()
    -- Reset mock state and module state before each test
    before_each(function()
        hs_mock.reset()
        stats.reset()
    end)

    ------------------------------------------------------
    -- formatBytes tests
    ------------------------------------------------------
    describe("formatBytes", function()
        it("formats gigabytes", function()
            assert.are.equal("1.5G", stats.formatBytes(1610612736))
        end)

        it("formats single digit gigabytes", function()
            assert.are.equal("1.0G", stats.formatBytes(1073741824))
        end)

        it("formats megabytes", function()
            assert.are.equal("256M", stats.formatBytes(268435456))
        end)

        it("formats single megabyte", function()
            assert.are.equal("1M", stats.formatBytes(1048576))
        end)

        it("formats kilobytes", function()
            assert.are.equal("512K", stats.formatBytes(524288))
        end)

        it("formats bytes", function()
            assert.are.equal("500B", stats.formatBytes(500))
        end)

        it("formats zero", function()
            assert.are.equal("0B", stats.formatBytes(0))
        end)
    end)

    ------------------------------------------------------
    -- calculateCpuPercent tests
    ------------------------------------------------------
    describe("calculateCpuPercent", function()
        it("calculates 50% usage with overall structure", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 200, system = 200, nice = 0, idle = 1000 }, n = 8 }
            -- Total delta = 400, Used delta = 200 (user+system), Idle delta = 200
            -- Used% = 200/400 = 50%
            assert.are.equal(50, stats.calculateCpuPercent(prev, curr))
        end)

        it("calculates 50% usage with flat structure (backward compat)", function()
            local prev = { user = 100, system = 100, nice = 0, idle = 800 }
            local curr = { user = 200, system = 200, nice = 0, idle = 1000 }
            assert.are.equal(50, stats.calculateCpuPercent(prev, curr))
        end)

        it("calculates 0% when all idle", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 100, system = 100, nice = 0, idle = 1000 }, n = 8 }
            -- Total delta = 200 (all idle)
            assert.are.equal(0, stats.calculateCpuPercent(prev, curr))
        end)

        it("calculates 100% when no idle", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 300, system = 200, nice = 0, idle = 800 }, n = 8 }
            -- Total delta = 300, Used delta = 300, Idle delta = 0
            assert.are.equal(100, stats.calculateCpuPercent(prev, curr))
        end)

        it("handles nil previous ticks", function()
            local curr = { overall = { user = 200, system = 200, nice = 0, idle = 900 }, n = 8 }
            assert.are.equal(0, stats.calculateCpuPercent(nil, curr))
        end)

        it("handles nil current ticks", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            assert.are.equal(0, stats.calculateCpuPercent(prev, nil))
        end)

        it("handles zero total delta", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            assert.are.equal(0, stats.calculateCpuPercent(prev, curr))
        end)

        it("handles missing user field gracefully", function()
            local prev = { overall = {} }
            local curr = { overall = {} }
            assert.are.equal(0, stats.calculateCpuPercent(prev, curr))
        end)
    end)

    ------------------------------------------------------
    -- formatRam tests
    ------------------------------------------------------
    describe("formatRam", function()
        it("formats RAM usage from vmStat", function()
            local vmStats = {
                pageSize = 4096,
                pagesWiredDown = 500000,
                pagesActive = 500000,
                pagesInactive = 200000,
                pagesFree = 100000,
            }
            -- Used = (500000 + 500000) * 4096 = 4,096,000,000 bytes = 3.8G
            assert.are.equal("3.8G", stats.formatRam(vmStats))
        end)

        it("handles nil vmStats", function()
            assert.are.equal("?", stats.formatRam(nil))
        end)

        it("uses provided pageSize", function()
            local vmStats = {
                pagesWiredDown = 250000,
                pagesActive = 250000,
            }
            -- Used = 500000 * 16384 = 8,192,000,000 bytes = 7.6G
            assert.are.equal("7.6G", stats.formatRam(vmStats, 16384))
        end)
    end)

    ------------------------------------------------------
    -- parseNetstat tests
    ------------------------------------------------------
    describe("parseNetstat", function()
        it("parses en0 bytes from netstat output", function()
            local output = [[
Name  Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0   16384 <Link#1>                        123456     0   12345678    98765     0    9876543     0
en0   1500  <Link#4>      aa:bb:cc:dd:ee:ff 234567     0 1234567890   345678     0  987654321     0
en1   1500  <Link#5>                             0     0          0        0     0          0     0
]]
            local result = stats.parseNetstat(output)
            assert.is_not_nil(result)
            assert.are.equal(1234567890, result.bytesIn)
            assert.are.equal(987654321, result.bytesOut)
        end)

        it("returns nil for empty output", function()
            assert.is_nil(stats.parseNetstat(""))
            assert.is_nil(stats.parseNetstat(nil))
        end)

        it("returns zeros if en0 not found", function()
            local output = [[
Name  Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0   16384 <Link#1>                        123456     0   12345678    98765     0    9876543     0
]]
            local result = stats.parseNetstat(output)
            assert.is_not_nil(result)
            assert.are.equal(0, result.bytesIn)
            assert.are.equal(0, result.bytesOut)
        end)
    end)

    ------------------------------------------------------
    -- formatNetworkSpeed tests
    ------------------------------------------------------
    describe("formatNetworkSpeed", function()
        it("formats download and upload speeds", function()
            local bytesDelta = { bytesIn = 10485760, bytesOut = 1048576 }  -- 10MB, 1MB
            local down, up = stats.formatNetworkSpeed(bytesDelta, 1)
            assert.are.equal("10M", down)
            assert.are.equal("1M", up)
        end)

        it("handles nil bytes delta", function()
            local down, up = stats.formatNetworkSpeed(nil, 1)
            assert.are.equal("?", down)
            assert.are.equal("?", up)
        end)

        it("handles zero time delta", function()
            local bytesDelta = { bytesIn = 1000, bytesOut = 500 }
            local down, up = stats.formatNetworkSpeed(bytesDelta, 0)
            assert.are.equal("?", down)
            assert.are.equal("?", up)
        end)
    end)

    ------------------------------------------------------
    -- formatBattery tests
    ------------------------------------------------------
    describe("formatBattery", function()
        it("formats battery with hours and minutes remaining", function()
            local result = stats.formatBattery(87, 180)  -- 87%, 3 hours
            assert.are.equal(" 87% 3h0m", result)
        end)

        it("formats battery with only minutes remaining", function()
            local result = stats.formatBattery(95, 45)  -- 95%, 45 minutes
            assert.are.equal(" 95% 45m", result)
        end)

        it("formats battery without time remaining", function()
            local result = stats.formatBattery(50, nil)
            assert.are.equal(" 50%", result)
        end)

        it("formats battery with zero time remaining", function()
            local result = stats.formatBattery(100, 0)
            assert.are.equal(" 100%", result)
        end)

        it("shows low battery icon when below 20%", function()
            local result = stats.formatBattery(15, 30)
            assert.are.equal(" 15% 30m", result)
        end)

        it("returns empty string for nil percentage", function()
            assert.are.equal("", stats.formatBattery(nil, 60))
        end)
    end)

    ------------------------------------------------------
    -- pomodoro tests
    ------------------------------------------------------
    describe("pomodoro", function()
        describe("getPomodoroSecondsRemaining", function()
            it("calculates remaining time", function()
                local endTime = 1000
                local currentTime = 700
                assert.are.equal(300, stats.getPomodoroSecondsRemaining(endTime, currentTime))
            end)

            it("returns 0 when time is up", function()
                local endTime = 1000
                local currentTime = 1100
                assert.are.equal(0, stats.getPomodoroSecondsRemaining(endTime, currentTime))
            end)

            it("returns 0 for nil endTime", function()
                assert.are.equal(0, stats.getPomodoroSecondsRemaining(nil, 1000))
            end)
        end)

        describe("formatPomodoroTime", function()
            it("formats 25 minutes as MM:SS", function()
                assert.are.equal("25:00", stats.formatPomodoroTime(1500))
            end)

            it("formats 5:30 as MM:SS", function()
                assert.are.equal("05:30", stats.formatPomodoroTime(330))
            end)

            it("formats 0:45 as MM:SS", function()
                assert.are.equal("00:45", stats.formatPomodoroTime(45))
            end)

            it("handles nil", function()
                assert.are.equal("00:00", stats.formatPomodoroTime(nil))
            end)

            it("handles negative", function()
                assert.are.equal("00:00", stats.formatPomodoroTime(-10))
            end)
        end)
    end)

    ------------------------------------------------------
    -- addToClipboardHistory tests
    ------------------------------------------------------
    describe("addToClipboardHistory", function()
        it("adds items to front of history", function()
            local history = {}
            stats.addToClipboardHistory("a", history, 10)
            stats.addToClipboardHistory("b", history, 10)
            stats.addToClipboardHistory("c", history, 10)
            assert.are.equal(3, #history)
            assert.are.equal("c", history[1])
            assert.are.equal("b", history[2])
            assert.are.equal("a", history[3])
        end)

        it("limits history to max items", function()
            local history = {}
            stats.addToClipboardHistory("a", history, 3)
            stats.addToClipboardHistory("b", history, 3)
            stats.addToClipboardHistory("c", history, 3)
            stats.addToClipboardHistory("d", history, 3)
            assert.are.equal(3, #history)
            assert.are.equal("d", history[1])
            assert.are.equal("c", history[2])
            assert.are.equal("b", history[3])
        end)

        it("moves duplicates to front", function()
            local history = {}
            stats.addToClipboardHistory("a", history, 10)
            stats.addToClipboardHistory("b", history, 10)
            stats.addToClipboardHistory("c", history, 10)
            stats.addToClipboardHistory("a", history, 10)  -- Duplicate
            assert.are.equal(3, #history)
            assert.are.equal("a", history[1])
            assert.are.equal("c", history[2])
            assert.are.equal("b", history[3])
        end)

        it("ignores empty strings", function()
            local history = {}
            stats.addToClipboardHistory("", history, 10)
            assert.are.equal(0, #history)
        end)

        it("ignores nil", function()
            local history = {}
            stats.addToClipboardHistory(nil, history, 10)
            assert.are.equal(0, #history)
        end)
    end)

    ------------------------------------------------------
    -- truncateText tests
    ------------------------------------------------------
    describe("truncateText", function()
        it("returns short text unchanged", function()
            assert.are.equal("hello", stats.truncateText("hello", 10))
        end)

        it("truncates long text with ellipsis", function()
            assert.are.equal("hello w...", stats.truncateText("hello world", 10))
        end)

        it("handles nil", function()
            assert.are.equal("", stats.truncateText(nil, 10))
        end)

        it("uses default max length", function()
            local longText = string.rep("a", 50)
            local result = stats.truncateText(longText)
            assert.are.equal(40, #result)
        end)
    end)

    ------------------------------------------------------
    -- buildMenuBarTitle tests (now simplified, each stat has own menubar)
    ------------------------------------------------------
    describe("buildMenuBarTitle", function()
        it("builds title with cpu and ram", function()
            local statsData = {
                cpu = 23,
                ram = "8.2G",
            }
            local title = stats.buildMenuBarTitle(statsData)
            assert.truthy(title:match("23%%"))
            assert.truthy(title:match("8.2G"))
        end)

        it("includes pomodoro when active", function()
            local statsData = {
                cpu = 10,
                pomodoro = "24:30",
            }
            local title = stats.buildMenuBarTitle(statsData)
            assert.truthy(title:match("24:30"))
        end)

        it("handles empty stats with icon", function()
            local title = stats.buildMenuBarTitle({})
            assert.truthy(title:match("📊"))
        end)
    end)

    ------------------------------------------------------
    -- caffeine toggle tests
    ------------------------------------------------------
    describe("toggleCaffeine", function()
        it("enables caffeine when off", function()
            stats._state.caffeineEnabled = false
            stats.toggleCaffeine()
            assert.is_true(stats._state.caffeineEnabled)
            assert.is_true(hs_mock.getCaffeineState().displayIdle)
            assert.is_true(hs_mock.getCaffeineState().systemIdle)
        end)

        it("disables caffeine when on", function()
            stats._state.caffeineEnabled = true
            stats.toggleCaffeine()
            assert.is_false(stats._state.caffeineEnabled)
            assert.is_false(hs_mock.getCaffeineState().displayIdle)
            assert.is_false(hs_mock.getCaffeineState().systemIdle)
        end)
    end)

    ------------------------------------------------------
    -- pomodoro timer tests
    ------------------------------------------------------
    describe("pomodoro timer", function()
        it("starts work session with 25 minutes", function()
            local mockTime = 1000
            stats._deps.getTime = function() return mockTime end

            stats.startPomodoroWork()

            assert.are.equal(1000 + 25 * 60, stats._state.pomodoroEndTime)
            assert.are.equal("work", stats._state.pomodoroMode)
        end)

        it("starts break session with 5 minutes", function()
            local mockTime = 2000
            stats._deps.getTime = function() return mockTime end

            stats.startPomodoroBreak()

            assert.are.equal(2000 + 5 * 60, stats._state.pomodoroEndTime)
            assert.are.equal("break", stats._state.pomodoroMode)
        end)

        it("stops pomodoro", function()
            stats._state.pomodoroEndTime = 5000
            stats._state.pomodoroMode = "work"
            stats._state.pomodoroTimer = hs.timer.doEvery(1, function() end)

            stats.stopPomodoro()

            assert.is_nil(stats._state.pomodoroEndTime)
            assert.is_nil(stats._state.pomodoroMode)
        end)
    end)

    ------------------------------------------------------
    -- menu bar lifecycle tests
    ------------------------------------------------------
    describe("start and stop", function()
        it("creates multiple menubars on start", function()
            stats.start()
            assert.is_not_nil(stats._state.cpuMenubar)
            assert.is_not_nil(stats._state.ramMenubar)
            assert.is_not_nil(stats._state.netMenubar)
            assert.is_not_nil(stats._state.batteryMenubar)
            assert.is_not_nil(stats._state.pomodoroMenubar)
            local menubars = hs_mock.getMenubars()
            assert.are.equal(5, #menubars)
        end)

        it("creates refresh timer on start", function()
            stats.start()
            assert.is_not_nil(stats._state.refreshTimer)
            local timers = hs_mock.getTimers()
            assert.is_true(#timers >= 1)
        end)

        it("creates clipboard watcher on start", function()
            stats.start()
            assert.is_not_nil(stats._state.clipboardWatcher)
            local watchers = hs_mock.getPasteboardWatchers()
            assert.are.equal(1, #watchers)
        end)

        it("cleans up on reset", function()
            stats.start()
            stats.reset()
            assert.is_nil(stats._state.cpuMenubar)
            assert.is_nil(stats._state.ramMenubar)
            assert.is_nil(stats._state.refreshTimer)
            assert.is_nil(stats._state.clipboardWatcher)
        end)
    end)

    ------------------------------------------------------
    -- clipboard history integration tests
    ------------------------------------------------------
    describe("clipboard watcher integration", function()
        it("adds copied text to history", function()
            stats.start()
            hs_mock.simulatePasteboardChange("hello world")
            assert.are.equal(1, #stats._state.clipboardHistory)
            assert.are.equal("hello world", stats._state.clipboardHistory[1])
        end)

        it("maintains history order with multiple copies", function()
            stats.start()
            hs_mock.simulatePasteboardChange("first")
            hs_mock.simulatePasteboardChange("second")
            hs_mock.simulatePasteboardChange("third")
            assert.are.equal(3, #stats._state.clipboardHistory)
            assert.are.equal("third", stats._state.clipboardHistory[1])
            assert.are.equal("second", stats._state.clipboardHistory[2])
            assert.are.equal("first", stats._state.clipboardHistory[3])
        end)
    end)

    ------------------------------------------------------
    -- buildMenu tests
    ------------------------------------------------------
    describe("buildMenu", function()
        it("includes caffeine toggle", function()
            stats._state.caffeineEnabled = false
            local menu = stats.buildMenu()
            local found = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Caffeine") then
                    found = true
                    assert.truthy(item.title:match("😴"))
                end
            end
            assert.is_true(found, "Should have caffeine menu item")
        end)

        it("shows awake icon when caffeine is on", function()
            stats._state.caffeineEnabled = true
            local menu = stats.buildMenu()
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Caffeine") then
                    assert.truthy(item.title:match("☕"))
                end
            end
        end)

        it("includes pomodoro options when not running", function()
            stats._state.pomodoroEndTime = nil
            local menu = stats.buildMenu()
            local foundWork = false
            local foundBreak = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Start Work") then foundWork = true end
                if item.title and item.title:match("Start Break") then foundBreak = true end
            end
            assert.is_true(foundWork, "Should have Start Work option")
            assert.is_true(foundBreak, "Should have Start Break option")
        end)

        it("includes clipboard history section", function()
            stats._state.clipboardHistory = { "item1", "item2" }
            local menu = stats.buildMenu()
            local foundHeader = false
            local foundItem = false
            for _, item in ipairs(menu) do
                if item.title == "Clipboard History" then foundHeader = true end
                if item.title and item.title:match("item1") then foundItem = true end
            end
            assert.is_true(foundHeader, "Should have Clipboard History header")
            assert.is_true(foundItem, "Should have history items")
        end)
    end)
end)
