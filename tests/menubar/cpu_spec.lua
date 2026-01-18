-- CPU Module Tests
-- Run with: busted tests/menubar/cpu_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local cpu = require("angus_scripts.menubar.cpu")

describe("CPU Module", function()
    before_each(function()
        hs_mock.reset()
        cpu.reset()
    end)

    describe("calculateCpuPercent", function()
        it("calculates 50% usage with overall structure", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 200, system = 200, nice = 0, idle = 1000 }, n = 8 }
            assert.are.equal(50, cpu.calculateCpuPercent(prev, curr))
        end)

        it("calculates 50% usage with flat structure", function()
            local prev = { user = 100, system = 100, nice = 0, idle = 800 }
            local curr = { user = 200, system = 200, nice = 0, idle = 1000 }
            assert.are.equal(50, cpu.calculateCpuPercent(prev, curr))
        end)

        it("calculates 0% when all idle", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 100, system = 100, nice = 0, idle = 1000 }, n = 8 }
            assert.are.equal(0, cpu.calculateCpuPercent(prev, curr))
        end)

        it("calculates 100% when no idle", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 300, system = 200, nice = 0, idle = 800 }, n = 8 }
            assert.are.equal(100, cpu.calculateCpuPercent(prev, curr))
        end)

        it("handles nil previous ticks", function()
            local curr = { overall = { user = 200, system = 200, nice = 0, idle = 900 }, n = 8 }
            assert.are.equal(0, cpu.calculateCpuPercent(nil, curr))
        end)

        it("handles nil current ticks", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            assert.are.equal(0, cpu.calculateCpuPercent(prev, nil))
        end)

        it("handles zero total delta", function()
            local prev = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            local curr = { overall = { user = 100, system = 100, nice = 0, idle = 800 }, n = 8 }
            assert.are.equal(0, cpu.calculateCpuPercent(prev, curr))
        end)
    end)

    describe("create", function()
        it("creates menubar", function()
            cpu.create()
            assert.is_not_nil(cpu._state.menubar)
            local menubars = hs_mock.getMenubars()
            assert.are.equal(1, #menubars)
        end)

        it("sets initial title", function()
            cpu.create()
            assert.are.equal("\u{2699} --%", cpu._state.menubar:title())  -- ⚙ --%
        end)
    end)

    describe("refresh", function()
        it("updates title with CPU percentage", function()
            -- Set up mock CPU ticks
            -- For 50%: totalDelta=200, usedDelta=100, idleDelta=100
            local ticksSequence = {
                { overall = { user = 100, system = 50, nice = 0, idle = 850 } },  -- total=1000
                { overall = { user = 150, system = 100, nice = 0, idle = 950 } }, -- total=1200, delta=200, idle_delta=100
            }
            local callCount = 0
            cpu._deps.cpuUsageTicks = function()
                callCount = callCount + 1
                return ticksSequence[callCount] or ticksSequence[#ticksSequence]
            end

            cpu.create()
            local cpuPct = cpu.refresh()

            assert.are.equal(50, cpuPct)
            assert.truthy(cpu._state.menubar:title():match("\u{2699} 50%%"))  -- ⚙ 50%
        end)
    end)

    describe("buildMenu", function()
        it("returns menu with header", function()
            cpu._deps.executeCommand = function(cmd)
                return [[
user    1234  12.3   1.5   1000   500  ??  S     1:00PM   0:30.00 /usr/bin/process
]]
            end

            cpu.create()
            local menu = cpu.buildMenu()

            assert.is_true(#menu >= 1)
            assert.are.equal("Top Processes by CPU", menu[1].title)
        end)

        it("includes process entries with kill submenu", function()
            cpu._deps.executeCommand = function(cmd)
                return [[
user    1234  12.3   1.5   1000   500  ??  S     1:00PM   0:30.00 /usr/bin/process
]]
            end

            cpu.create()
            local menu = cpu.buildMenu()

            -- Find the process entry (should have a submenu)
            local foundProcess = false
            for _, item in ipairs(menu) do
                if item.menu then
                    foundProcess = true
                    assert.truthy(item.menu[1].title:match("Kill"))
                end
            end
            assert.is_true(foundProcess)
        end)
    end)

    describe("destroy", function()
        it("cleans up menubar", function()
            cpu.create()
            cpu.destroy()
            assert.is_nil(cpu._state.menubar)
        end)
    end)
end)
