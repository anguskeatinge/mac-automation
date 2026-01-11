-- Window Manager Tests
-- Run with: busted tests/window_manager_spec.lua

-- Set up package path to find our modules
package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

-- Load the mock before loading window_manager (so it gets the mock `hs`)
local hs_mock = require("tests.mocks.hs_mock")

-- Make hs_mock available as global `hs` before requiring window_manager
_G.hs = hs_mock

-- Now load the window manager
local wm = require("angus_scripts.window_manager")

describe("Window Manager", function()
    -- Reset mock state before each test
    before_each(function()
        hs_mock.reset()
    end)

    describe("smartRight", function()
        it("should move to right half with FULL height from arbitrary position", function()
            -- Setup: window at some arbitrary position (not half screen)
            -- Screen: 1920x1080 at (0,0)
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })

            -- Window: 400x300 at position (100, 200) - some random spot
            hs_mock.setFocusedWindow({ x = 100, y = 200, w = 400, h = 300 }, screen)

            -- Act
            wm.smartRight()

            -- Assert: should be at right half with FULL height
            local frame = hs_mock.getLastSetFrame()
            assert.is_not_nil(frame, "Expected setFrame to be called")
            assert.are.equal(960, frame.x, "x should be 0.5 * 1920 = 960")
            assert.are.equal(0, frame.y, "y should be 0 (full height)")
            assert.are.equal(960, frame.w, "w should be 0.5 * 1920 = 960")
            assert.are.equal(1080, frame.h, "h should be full height 1080")
        end)

        it("should move to next screen when already at right half full height", function()
            -- Setup: dual screens, window at right half full height on screen 1
            local screen1, screen2 = hs_mock.setupDualScreens(
                { x = 0, y = 0, w = 1920, h = 1080 },
                { x = 1920, y = 0, w = 1920, h = 1080 }
            )

            -- Window: right half of screen 1 with full height
            hs_mock.setFocusedWindow({ x = 960, y = 0, w = 960, h = 1080 }, screen1)

            -- Act
            wm.smartRight()

            -- Assert: should be at LEFT half of screen 2
            local frame = hs_mock.getLastSetFrame()
            assert.is_not_nil(frame, "Expected setFrame to be called")
            assert.are.equal(1920, frame.x, "x should be start of screen2 = 1920")
            assert.are.equal(0, frame.y, "y should be 0")
            assert.are.equal(960, frame.w, "w should be 0.5 * 1920 = 960")
            assert.are.equal(1080, frame.h, "h should be 1080")
        end)
    end)

    describe("smartLeft", function()
        it("should move to left half with FULL height from arbitrary position", function()
            -- Setup: window at some arbitrary position
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })

            -- Window: 400x300 at position (800, 200) - some random spot
            hs_mock.setFocusedWindow({ x = 800, y = 200, w = 400, h = 300 }, screen)

            -- Act
            wm.smartLeft()

            -- Assert: should be at left half with FULL height
            local frame = hs_mock.getLastSetFrame()
            assert.is_not_nil(frame, "Expected setFrame to be called")
            assert.are.equal(0, frame.x, "x should be 0")
            assert.are.equal(0, frame.y, "y should be 0 (full height)")
            assert.are.equal(960, frame.w, "w should be 0.5 * 1920 = 960")
            assert.are.equal(1080, frame.h, "h should be full height 1080")
        end)

        it("should move to previous screen when already at left half full height", function()
            -- Setup: dual screens, window at left half full height on screen 2
            local screen1, screen2 = hs_mock.setupDualScreens(
                { x = 0, y = 0, w = 1920, h = 1080 },
                { x = 1920, y = 0, w = 1920, h = 1080 }
            )

            -- Window: left half of screen 2 with full height
            hs_mock.setFocusedWindow({ x = 1920, y = 0, w = 960, h = 1080 }, screen2)

            -- Act
            wm.smartLeft()

            -- Assert: should be at RIGHT half of screen 1
            local frame = hs_mock.getLastSetFrame()
            assert.is_not_nil(frame, "Expected setFrame to be called")
            assert.are.equal(960, frame.x, "x should be right half of screen1 = 960")
            assert.are.equal(0, frame.y, "y should be 0")
            assert.are.equal(960, frame.w, "w should be 0.5 * 1920 = 960")
            assert.are.equal(1080, frame.h, "h should be 1080")
        end)
    end)

    describe("keybindings", function()
        it("should bind backtick to threeQuarterWidth", function()
            -- Act
            wm.bindHotkeys()

            -- Assert
            local hk = hs_mock.findHotkey("`")
            assert.is_not_nil(hk, "Expected backtick hotkey to be bound")
            assert.are.equal(wm.threeQuarterWidth, hk.fn, "backtick should call threeQuarterWidth")
        end)

        it("should bind '1' to twoThirdWidth", function()
            wm.bindHotkeys()
            local hk = hs_mock.findHotkey("1")
            assert.is_not_nil(hk, "Expected '1' hotkey to be bound")
            assert.are.equal(wm.twoThirdWidth, hk.fn, "'1' should call twoThirdWidth")
        end)

        it("should bind '2' to halfWidth", function()
            wm.bindHotkeys()
            local hk = hs_mock.findHotkey("2")
            assert.is_not_nil(hk, "Expected '2' hotkey to be bound")
            assert.are.equal(wm.halfWidth, hk.fn, "'2' should call halfWidth")
        end)

        it("should bind '3' to oneThirdWidth", function()
            wm.bindHotkeys()
            local hk = hs_mock.findHotkey("3")
            assert.is_not_nil(hk, "Expected '3' hotkey to be bound")
            assert.are.equal(wm.oneThirdWidth, hk.fn, "'3' should call oneThirdWidth")
        end)

        it("should bind '4' to oneQuarterWidth", function()
            wm.bindHotkeys()
            local hk = hs_mock.findHotkey("4")
            assert.is_not_nil(hk, "Expected '4' hotkey to be bound")
            assert.are.equal(wm.oneQuarterWidth, hk.fn, "'4' should call oneQuarterWidth")
        end)

        it("should NOT bind '5' to anything", function()
            wm.bindHotkeys()
            local hk = hs_mock.findHotkey("5")
            assert.is_nil(hk, "Expected '5' hotkey to NOT be bound")
        end)
    end)
end)
