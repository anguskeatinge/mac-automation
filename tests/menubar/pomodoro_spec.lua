-- Pomodoro Module Tests
-- Run with: busted tests/menubar/pomodoro_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local pomodoro = require("angus_scripts.menubar.pomodoro")

describe("Pomodoro Module", function()
    before_each(function()
        hs_mock.reset()
        pomodoro.reset()
    end)

    describe("startPomodoroWork", function()
        it("sets end time 25 minutes in future", function()
            local mockTime = 1000
            pomodoro._deps.getTime = function() return mockTime end

            pomodoro.startPomodoroWork()

            assert.are.equal(1000 + 25 * 60, pomodoro.getPomodoroEndTime())
            assert.are.equal("work", pomodoro.getPomodoroMode())
        end)
    end)

    describe("startPomodoroBreak", function()
        it("sets end time 5 minutes in future", function()
            local mockTime = 2000
            pomodoro._deps.getTime = function() return mockTime end

            pomodoro.startPomodoroBreak()

            assert.are.equal(2000 + 5 * 60, pomodoro.getPomodoroEndTime())
            assert.are.equal("break", pomodoro.getPomodoroMode())
        end)
    end)

    describe("stopPomodoro", function()
        it("clears pomodoro state", function()
            pomodoro._deps.getTime = function() return 1000 end
            pomodoro.startPomodoroWork()

            pomodoro.stopPomodoro()

            assert.is_nil(pomodoro.getPomodoroEndTime())
            assert.is_nil(pomodoro.getPomodoroMode())
        end)
    end)

    describe("onClipboardChange", function()
        it("adds text to clipboard history", function()
            pomodoro.onClipboardChange("test text")
            local history = pomodoro.getClipboardHistory()
            assert.are.equal(1, #history)
            assert.are.equal("test text", history[1])
        end)

        it("maintains order with multiple items", function()
            pomodoro.onClipboardChange("first")
            pomodoro.onClipboardChange("second")
            pomodoro.onClipboardChange("third")

            local history = pomodoro.getClipboardHistory()
            assert.are.equal(3, #history)
            assert.are.equal("third", history[1])
            assert.are.equal("second", history[2])
            assert.are.equal("first", history[3])
        end)
    end)

    describe("create", function()
        it("creates menubar", function()
            pomodoro.create()
            assert.is_not_nil(pomodoro._state.menubar)
            local menubars = hs_mock.getMenubars()
            assert.are.equal(1, #menubars)
        end)

        it("sets timer icon as initial title", function()
            pomodoro.create()
            assert.are.equal("\u{23F1}", pomodoro._state.menubar:title())  -- ⏱
        end)

        it("creates clipboard watcher", function()
            pomodoro.create()
            assert.is_not_nil(pomodoro._state.clipboardWatcher)
            local watchers = hs_mock.getPasteboardWatchers()
            assert.are.equal(1, #watchers)
        end)
    end)

    describe("refresh", function()
        it("shows timer when pomodoro is active", function()
            pomodoro._deps.getTime = function() return 1000 end

            pomodoro.create()
            pomodoro.startPomodoroWork()

            -- Advance time by 5 minutes
            pomodoro._deps.getTime = function() return 1300 end
            local remaining = pomodoro.refresh()

            assert.are.equal("20:00", remaining)
            assert.are.equal("\u{23F1}20:00", pomodoro._state.menubar:title())  -- ⏱20:00
        end)

        it("shows only timer icon when no timer", function()
            pomodoro._deps.getTime = function() return 1000 end

            pomodoro.create()
            pomodoro.refresh()

            assert.are.equal("\u{23F1}", pomodoro._state.menubar:title())  -- ⏱
        end)
    end)

    describe("buildMenu", function()
        it("shows start options when timer not running", function()
            pomodoro._deps.getTime = function() return 1000 end
            pomodoro.create()

            local menu = pomodoro.buildMenu()

            local foundWork = false
            local foundBreak = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Start Work") then foundWork = true end
                if item.title and item.title:match("Start Break") then foundBreak = true end
            end
            assert.is_true(foundWork)
            assert.is_true(foundBreak)
        end)

        it("shows stop option when timer running", function()
            pomodoro._deps.getTime = function() return 1000 end
            pomodoro.create()
            pomodoro.startPomodoroWork()

            local menu = pomodoro.buildMenu()

            local foundStop = false
            for _, item in ipairs(menu) do
                if item.title and item.title == "Stop" then foundStop = true end
            end
            assert.is_true(foundStop)
        end)

        it("includes clipboard history section", function()
            pomodoro._deps.getTime = function() return 1000 end
            pomodoro.create()
            pomodoro.onClipboardChange("test item")

            local menu = pomodoro.buildMenu()

            local foundHeader = false
            local foundItem = false
            for _, item in ipairs(menu) do
                if item.title == "Clipboard History" then foundHeader = true end
                if item.title and item.title:match("test item") then foundItem = true end
            end
            assert.is_true(foundHeader)
            assert.is_true(foundItem)
        end)
    end)

    describe("destroy", function()
        it("cleans up all state", function()
            pomodoro._deps.getTime = function() return 1000 end
            pomodoro.create()
            pomodoro.startPomodoroWork()
            pomodoro.onClipboardChange("test")

            pomodoro.destroy()

            assert.is_nil(pomodoro._state.menubar)
            assert.is_nil(pomodoro._state.clipboardWatcher)
            assert.is_nil(pomodoro.getPomodoroEndTime())
            assert.are.equal(0, #pomodoro.getClipboardHistory())
        end)
    end)
end)
