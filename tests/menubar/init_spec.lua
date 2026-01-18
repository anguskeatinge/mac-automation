-- Menubar Init (Orchestrator) Tests
-- Run with: busted tests/menubar/init_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local menubar = require("angus_scripts.menubar")

describe("Menubar Orchestrator", function()
    before_each(function()
        hs_mock.reset()
        menubar.reset()
    end)

    describe("start", function()
        it("creates all menubars", function()
            menubar.start()

            local menubars = hs_mock.getMenubars()
            assert.are.equal(5, #menubars)  -- cpu, ram, network, battery, pomodoro
        end)

        it("creates refresh timer", function()
            menubar.start()

            local timers = hs_mock.getTimers()
            assert.is_true(#timers >= 1)
        end)

        it("exposes submodules", function()
            assert.is_not_nil(menubar.cpu)
            assert.is_not_nil(menubar.ram)
            assert.is_not_nil(menubar.network)
            assert.is_not_nil(menubar.battery)
            assert.is_not_nil(menubar.pomodoro)
        end)
    end)

    describe("stop", function()
        it("cleans up all menubars and timers", function()
            menubar.start()
            menubar.stop()

            assert.is_nil(menubar._state.refreshTimer)
            assert.is_nil(menubar.cpu._state.menubar)
            assert.is_nil(menubar.ram._state.menubar)
            assert.is_nil(menubar.network._state.menubar)
            assert.is_nil(menubar.battery._state.menubar)
            assert.is_nil(menubar.pomodoro._state.menubar)
        end)
    end)

    describe("refresh", function()
        it("refreshes all modules without error", function()
            menubar.start()

            -- Should not throw
            assert.has_no.errors(function()
                menubar.refresh()
            end)
        end)
    end)
end)
