-- Utils Tests
-- Run with: busted tests/menubar/utils_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local utils = require("angus_scripts.menubar.utils")

describe("Menubar Utils", function()
    before_each(function()
        hs_mock.reset()
    end)

    describe("formatBytes", function()
        it("formats gigabytes", function()
            assert.are.equal("1.5G", utils.formatBytes(1610612736))
        end)

        it("formats single digit gigabytes", function()
            assert.are.equal("1.0G", utils.formatBytes(1073741824))
        end)

        it("formats megabytes", function()
            assert.are.equal("256M", utils.formatBytes(268435456))
        end)

        it("formats single megabyte", function()
            assert.are.equal("1M", utils.formatBytes(1048576))
        end)

        it("formats kilobytes", function()
            assert.are.equal("512K", utils.formatBytes(524288))
        end)

        it("formats bytes", function()
            assert.are.equal("500B", utils.formatBytes(500))
        end)

        it("formats zero", function()
            assert.are.equal("0B", utils.formatBytes(0))
        end)

        it("handles nil", function()
            assert.are.equal("0B", utils.formatBytes(nil))
        end)

        it("handles negative", function()
            assert.are.equal("0B", utils.formatBytes(-100))
        end)
    end)

    describe("truncateText", function()
        it("returns short text unchanged", function()
            assert.are.equal("hello", utils.truncateText("hello", 10))
        end)

        it("truncates long text with ellipsis", function()
            assert.are.equal("hello w...", utils.truncateText("hello world", 10))
        end)

        it("handles nil", function()
            assert.are.equal("", utils.truncateText(nil, 10))
        end)

        it("uses default max length", function()
            local longText = string.rep("a", 50)
            local result = utils.truncateText(longText)
            assert.are.equal(40, #result)
        end)
    end)

    describe("formatPomodoroTime", function()
        it("formats 25 minutes as MM:SS", function()
            assert.are.equal("25:00", utils.formatPomodoroTime(1500))
        end)

        it("formats 5:30 as MM:SS", function()
            assert.are.equal("05:30", utils.formatPomodoroTime(330))
        end)

        it("formats 0:45 as MM:SS", function()
            assert.are.equal("00:45", utils.formatPomodoroTime(45))
        end)

        it("handles nil", function()
            assert.are.equal("00:00", utils.formatPomodoroTime(nil))
        end)

        it("handles negative", function()
            assert.are.equal("00:00", utils.formatPomodoroTime(-10))
        end)
    end)

    describe("getPomodoroSecondsRemaining", function()
        it("calculates remaining time", function()
            assert.are.equal(300, utils.getPomodoroSecondsRemaining(1000, 700))
        end)

        it("returns 0 when time is up", function()
            assert.are.equal(0, utils.getPomodoroSecondsRemaining(1000, 1100))
        end)

        it("returns 0 for nil endTime", function()
            assert.are.equal(0, utils.getPomodoroSecondsRemaining(nil, 1000))
        end)
    end)

    describe("addToClipboardHistory", function()
        it("adds items to front of history", function()
            local history = {}
            utils.addToClipboardHistory("a", history, 10)
            utils.addToClipboardHistory("b", history, 10)
            utils.addToClipboardHistory("c", history, 10)
            assert.are.equal(3, #history)
            assert.are.equal("c", history[1])
            assert.are.equal("b", history[2])
            assert.are.equal("a", history[3])
        end)

        it("limits history to max items", function()
            local history = {}
            utils.addToClipboardHistory("a", history, 3)
            utils.addToClipboardHistory("b", history, 3)
            utils.addToClipboardHistory("c", history, 3)
            utils.addToClipboardHistory("d", history, 3)
            assert.are.equal(3, #history)
            assert.are.equal("d", history[1])
            assert.are.equal("c", history[2])
            assert.are.equal("b", history[3])
        end)

        it("moves duplicates to front", function()
            local history = {}
            utils.addToClipboardHistory("a", history, 10)
            utils.addToClipboardHistory("b", history, 10)
            utils.addToClipboardHistory("c", history, 10)
            utils.addToClipboardHistory("a", history, 10)
            assert.are.equal(3, #history)
            assert.are.equal("a", history[1])
            assert.are.equal("c", history[2])
            assert.are.equal("b", history[3])
        end)

        it("ignores empty strings", function()
            local history = {}
            utils.addToClipboardHistory("", history, 10)
            assert.are.equal(0, #history)
        end)

        it("ignores nil", function()
            local history = {}
            utils.addToClipboardHistory(nil, history, 10)
            assert.are.equal(0, #history)
        end)
    end)

    describe("parsePsOutput", function()
        it("parses ps aux output", function()
            local output = [[
user    1234  12.3   1.5   1000   500  ??  S     1:00PM   0:30.00 /usr/bin/process
user    5678   5.6   0.8    800   400  ??  R     2:00PM   0:10.00 /Applications/App.app/Contents/MacOS/App
]]
            local processes = utils.parsePsOutput(output)
            assert.are.equal(2, #processes)
            assert.are.equal("process", processes[1].name)
            assert.are.equal(12.3, processes[1].cpu)
            assert.are.equal(1234, processes[1].pid)
            assert.are.equal("App", processes[2].name)
            assert.are.equal(5.6, processes[2].cpu)
            assert.are.equal(5678, processes[2].pid)
        end)

        it("returns empty for nil output", function()
            local processes = utils.parsePsOutput(nil)
            assert.are.equal(0, #processes)
        end)

        it("returns empty for empty output", function()
            local processes = utils.parsePsOutput("")
            assert.are.equal(0, #processes)
        end)
    end)

    describe("parseNettopOutput", function()
        it("parses nettop output", function()
            local output = [[
Chrome.1234, 1024, 512
Safari.5678, 2048, 1024
]]
            local processes = utils.parseNettopOutput(output)
            assert.are.equal(2, #processes)
            assert.are.equal("Chrome", processes[1].name)
            assert.are.equal(1234, processes[1].pid)
            assert.are.equal(1024, processes[1].bytesIn)
            assert.are.equal(512, processes[1].bytesOut)
        end)

        it("returns empty for nil output", function()
            local processes = utils.parseNettopOutput(nil)
            assert.are.equal(0, #processes)
        end)

        it("returns empty for empty output", function()
            local processes = utils.parseNettopOutput("")
            assert.are.equal(0, #processes)
        end)
    end)
end)
