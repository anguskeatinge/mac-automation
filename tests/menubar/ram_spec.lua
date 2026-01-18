-- RAM Module Tests
-- Run with: busted tests/menubar/ram_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local ram = require("angus_scripts.menubar.ram")

describe("RAM Module", function()
    before_each(function()
        hs_mock.reset()
        ram.reset()
    end)

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
            assert.are.equal("3.8G", ram.formatRam(vmStats))
        end)

        it("handles nil vmStats", function()
            assert.are.equal("?", ram.formatRam(nil))
        end)

        it("uses provided pageSize", function()
            local vmStats = {
                pagesWiredDown = 250000,
                pagesActive = 250000,
            }
            -- Used = 500000 * 16384 = 8,192,000,000 bytes = 7.6G
            assert.are.equal("7.6G", ram.formatRam(vmStats, 16384))
        end)
    end)

    describe("create", function()
        it("creates menubar", function()
            ram.create()
            assert.is_not_nil(ram._state.menubar)
            local menubars = hs_mock.getMenubars()
            assert.are.equal(1, #menubars)
        end)

        it("sets initial title", function()
            ram.create()
            assert.are.equal("\u{25A6} --", ram._state.menubar:title())  -- ▦ --
        end)
    end)

    describe("refresh", function()
        it("updates title with RAM usage", function()
            ram._deps.vmStat = function()
                return {
                    pageSize = 4096,
                    pagesWiredDown = 500000,
                    pagesActive = 500000,
                }
            end

            ram.create()
            local ramStr = ram.refresh()

            assert.are.equal("3.8G", ramStr)
            assert.truthy(ram._state.menubar:title():match("\u{25A6} 3.8G"))  -- ▦ 3.8G
        end)
    end)

    describe("buildMenu", function()
        it("returns menu with header", function()
            ram._deps.executeCommand = function(cmd)
                return [[
user    1234  1.5   12.3   1000   500000  ??  S     1:00PM   0:30.00 /usr/bin/process
]]
            end

            ram.create()
            local menu = ram.buildMenu()

            assert.is_true(#menu >= 1)
            assert.are.equal("Top Apps by Memory", menu[1].title)
        end)

        it("includes process entries with formatted memory", function()
            ram._deps.executeCommand = function(cmd)
                return [[
user    1234  1.5   12.3   1000   524288  ??  S     1:00PM   0:30.00 /usr/bin/process
]]
            end

            ram.create()
            local menu = ram.buildMenu()

            -- Find the process entry with memory display (524288 KB = 512 MB)
            local foundProcess = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("512M") then
                    foundProcess = true
                end
            end
            assert.is_true(foundProcess)
        end)

        it("groups processes by app name", function()
            ram._deps.executeCommand = function(cmd)
                return [[
user    1234  1.5   12.3   1000   409600  ??  S     1:00PM   0:30.00 /Applications/Chrome.app/Contents/MacOS/Chrome
user    1235  0.5    2.0   1000   102400  ??  S     1:00PM   0:30.00 /Applications/Chrome.app/Contents/MacOS/Chrome Helper
user    5678  3.0    5.0   1000   204800  ??  S     1:00PM   0:30.00 /usr/bin/python3
]]
            end

            ram.create()
            local menu = ram.buildMenu()

            -- Find Chrome group header
            local foundChrome = false
            local foundPython = false
            for _, item in ipairs(menu) do
                if item.title and item.title:match("Chrome") and item.title:match("%(2%)") then
                    foundChrome = true
                    -- Should show total memory (409600 + 102400 = 512000 KB = 500M)
                    assert.truthy(item.title:match("500M"))
                end
                if item.title and item.title:match("python3") then
                    foundPython = true
                end
            end
            assert.is_true(foundChrome)
            assert.is_true(foundPython)
        end)
    end)

    describe("destroy", function()
        it("cleans up menubar", function()
            ram.create()
            ram.destroy()
            assert.is_nil(ram._state.menubar)
        end)
    end)
end)
