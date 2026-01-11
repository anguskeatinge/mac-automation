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

    ------------------------------------------------------
    -- Width Cycling Tests
    ------------------------------------------------------

    describe("halfWidth", function()
        it("should move to left half from arbitrary position", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            hs_mock.setFocusedWindow({ x = 100, y = 200, w = 400, h = 300 }, screen)

            wm.halfWidth()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "x should be 0 (left aligned)")
            assert.are.equal(0, frame.y, "y should be 0")
            assert.are.equal(960, frame.w, "w should be 0.5 * 1920 = 960")
            assert.are.equal(1080, frame.h, "h should be full height")
        end)

        it("should cycle left -> right -> left", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })

            -- Start at left half
            hs_mock.setFocusedWindow({ x = 0, y = 0, w = 960, h = 1080 }, screen)
            wm.halfWidth()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(960, frame.x, "After 1st press: x should be 960 (right half)")

            -- Now at right half, press again
            hs_mock.setFocusedWindow({ x = 960, y = 0, w = 960, h = 1080 }, screen)
            wm.halfWidth()

            frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "After 2nd press: x should be 0 (back to left)")
        end)
    end)

    describe("oneThirdWidth", function()
        it("should cycle through left -> middle -> right -> left", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })

            -- Start at left third
            hs_mock.setFocusedWindow({ x = 0, y = 0, w = 640, h = 1080 }, screen)
            wm.oneThirdWidth()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(640, frame.x, "After 1st press: x should be 640 (middle third)")

            -- Now at middle third
            hs_mock.setFocusedWindow({ x = 640, y = 0, w = 640, h = 1080 }, screen)
            wm.oneThirdWidth()

            frame = hs_mock.getLastSetFrame()
            assert.are.equal(1280, frame.x, "After 2nd press: x should be 1280 (right third)")

            -- Now at right third
            hs_mock.setFocusedWindow({ x = 1280, y = 0, w = 640, h = 1080 }, screen)
            wm.oneThirdWidth()

            frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "After 3rd press: x should be 0 (back to left)")
        end)
    end)

    describe("right-side preservation", function()
        it("should stay right-aligned when switching from 1/3 to 1/2 width", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })

            -- Window at right third (x = 2/3 * 1920 = 1280, w = 1/3 * 1920 = 640)
            hs_mock.setFocusedWindow({ x = 1280, y = 0, w = 640, h = 1080 }, screen)

            wm.halfWidth()

            local frame = hs_mock.getLastSetFrame()
            -- Should be right-aligned at half width: x = 0.5 * 1920 = 960
            assert.are.equal(960, frame.x, "x should be 960 (right-aligned at half)")
            assert.are.equal(960, frame.w, "w should be 960 (half width)")
        end)
    end)

    ------------------------------------------------------
    -- Edge Cases
    ------------------------------------------------------

    describe("edge cases", function()
        it("should not crash when no window is focused", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Don't set a focused window

            -- These should all return early without crashing
            assert.has_no.errors(function() wm.smartRight() end)
            assert.has_no.errors(function() wm.smartLeft() end)
            assert.has_no.errors(function() wm.smartUp() end)
            assert.has_no.errors(function() wm.smartDown() end)
            assert.has_no.errors(function() wm.halfWidth() end)
            assert.has_no.errors(function() wm.maximize() end)
        end)
    end)

    ------------------------------------------------------
    -- smartUp/smartDown Tests
    ------------------------------------------------------

    describe("smartUp", function()
        it("should move to top half and preserve width from arbitrary position", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Window at some position with specific width (right third)
            hs_mock.setFocusedWindow({ x = 1280, y = 400, w = 640, h = 300 }, screen)

            wm.smartUp()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(1280, frame.x, "x should be preserved at 1280")
            assert.are.equal(0, frame.y, "y should be 0 (top)")
            assert.are.equal(640, frame.w, "w should be preserved at 640")
            assert.are.equal(540, frame.h, "h should be 540 (top half)")
        end)

        it("should move from bottom half to top half preserving width", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Window at bottom half, left side
            hs_mock.setFocusedWindow({ x = 0, y = 540, w = 960, h = 540 }, screen)

            wm.smartUp()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "x should be preserved at 0")
            assert.are.equal(0, frame.y, "y should be 0 (top)")
            assert.are.equal(960, frame.w, "w should be preserved at 960")
            assert.are.equal(540, frame.h, "h should be 540 (half height)")
        end)
    end)

    describe("smartDown", function()
        it("should move to bottom half and preserve width from arbitrary position", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Window at some position with specific width (left third)
            hs_mock.setFocusedWindow({ x = 0, y = 100, w = 640, h = 300 }, screen)

            wm.smartDown()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "x should be preserved at 0")
            assert.are.equal(540, frame.y, "y should be 540 (bottom half)")
            assert.are.equal(640, frame.w, "w should be preserved at 640")
            assert.are.equal(540, frame.h, "h should be 540 (bottom half)")
        end)
    end)

    ------------------------------------------------------
    -- Q/E Screen Cycling Tests (kept old 3-step behavior)
    ------------------------------------------------------

    describe("cycleScreenQ", function()
        it("should move to left half keeping current height from arbitrary position", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Window at some position with partial height
            hs_mock.setFocusedWindow({ x = 800, y = 200, w = 400, h = 300 }, screen)

            wm.cycleScreenQ()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "x should be 0 (left)")
            assert.are.equal(200, frame.y, "y should be preserved at 200")
            assert.are.equal(960, frame.w, "w should be 960 (half)")
            assert.are.equal(300, frame.h, "h should be preserved at 300")
        end)

        it("should expand to full height when at left half with partial height", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Window at left half with partial height
            hs_mock.setFocusedWindow({ x = 0, y = 200, w = 960, h = 300 }, screen)

            wm.cycleScreenQ()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(0, frame.x, "x should be 0")
            assert.are.equal(0, frame.y, "y should be 0 (full height)")
            assert.are.equal(960, frame.w, "w should be 960")
            assert.are.equal(1080, frame.h, "h should be 1080 (full height)")
        end)

        it("should move to previous screen when at left half full height", function()
            local screen1, screen2 = hs_mock.setupDualScreens(
                { x = 0, y = 0, w = 1920, h = 1080 },
                { x = 1920, y = 0, w = 1920, h = 1080 }
            )
            -- Window at left half full height on screen 2
            hs_mock.setFocusedWindow({ x = 1920, y = 0, w = 960, h = 1080 }, screen2)

            wm.cycleScreenQ()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(960, frame.x, "x should be 960 (right half of screen1)")
            assert.are.equal(0, frame.y, "y should be 0")
            assert.are.equal(960, frame.w, "w should be 960")
            assert.are.equal(1080, frame.h, "h should be 1080")
        end)
    end)

    describe("cycleScreenE", function()
        it("should move to right half keeping current height from arbitrary position", function()
            local screen = hs_mock.setupSingleScreen({ x = 0, y = 0, w = 1920, h = 1080 })
            -- Window at some position with partial height
            hs_mock.setFocusedWindow({ x = 100, y = 150, w = 400, h = 400 }, screen)

            wm.cycleScreenE()

            local frame = hs_mock.getLastSetFrame()
            assert.are.equal(960, frame.x, "x should be 960 (right half)")
            assert.are.equal(150, frame.y, "y should be preserved at 150")
            assert.are.equal(960, frame.w, "w should be 960 (half)")
            assert.are.equal(400, frame.h, "h should be preserved at 400")
        end)
    end)
end)
