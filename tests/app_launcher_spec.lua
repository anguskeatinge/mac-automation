package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local launcher = require("angus_scripts.app_launcher")

local apps = {
    { name = "Google Chrome", bundleID = "com.google.Chrome" },
    { name = "iTerm", bundleID = "com.googlecode.iterm2" },
    { name = "Terminal", bundleID = "com.apple.Terminal" },
    { name = "TextEdit", bundleID = "com.apple.TextEdit" },
    { name = "Telegram", bundleID = "ru.keepcoder.Telegram" },
    { name = "Chess", bundleID = "com.apple.Chess" },
}

describe("App launcher", function()
    before_each(function()
        hs_mock.reset()
        launcher.reset()
    end)

    it("maps ch to Chrome", function()
        local alias = launcher.resolveAlias("ch")
        assert.are.equal("com.google.Chrome", alias.bundleID)
    end)

    it("maps te to iTerm", function()
        local alias = launcher.resolveAlias("TE")
        assert.are.equal("com.googlecode.iterm2", alias.bundleID)
    end)

    it("puts Chrome first for ch even when Chess exists", function()
        local ranked = launcher.rankApps(apps, "ch")
        assert.are.equal("Google Chrome", ranked[1].name)
        assert.are.equal(1000, ranked[1].score)
    end)

    it("puts iTerm first for te and hides Terminal", function()
        local ranked = launcher.rankApps(apps, "te")
        assert.are.equal("iTerm", ranked[1].name)
        for _, item in ipairs(ranked) do
            assert.are_not.equal("com.apple.Terminal", item.bundleID)
        end
    end)

    it("hides Terminal for term and keeps iTerm first", function()
        local ranked = launcher.rankApps(apps, "term")
        assert.are.equal("iTerm", ranked[1].name)
        for _, item in ipairs(ranked) do
            assert.are_not.equal("com.apple.Terminal", item.bundleID)
        end
    end)

    it("only shows Terminal for the full word", function()
        local ranked = launcher.rankApps(apps, "terminal")
        assert.are.equal("Terminal", ranked[1].name)
    end)

    it("shows pinned Chrome, iTerm, and Spotlight when the query is empty", function()
        local ranked = launcher.rankApps(apps, "")
        assert.are.equal(3, #ranked)
        assert.are.equal("Google Chrome", ranked[1].name)
        assert.are.equal("iTerm", ranked[2].name)
        assert.are.equal("Spotlight", ranked[3].name)
        assert.are.equal("spotlight", ranked[3].action)
    end)

    it("maps sp to Spotlight", function()
        local ranked = launcher.rankApps(apps, "sp")
        assert.are.equal("Spotlight", ranked[1].name)
        assert.are.equal("spotlight", ranked[1].action)
    end)

    it("toggles closed when already visible", function()
        local hidden = false
        local shown = false
        launcher._state.visible = true
        launcher._state.chooser = {
            hide = function()
                hidden = true
            end,
            show = function()
                shown = true
            end,
            query = function() end,
            choices = function() end,
        }
        assert.are.equal("hide", launcher.toggle())
        assert.is_true(hidden)
        assert.is_false(shown)
        assert.is_false(launcher._state.visible)
    end)

    it("toggles open when hidden", function()
        local shown = false
        launcher._state.visible = false
        launcher._state.emptyChoices = {}
        launcher._state.chooser = {
            hide = function() end,
            show = function()
                shown = true
            end,
            query = function() end,
            choices = function() end,
        }
        assert.are.equal("show", launcher.toggle())
        assert.is_true(shown)
        assert.is_true(launcher._state.visible)
    end)

    it("treats cmd-space as the close chord while open", function()
        local event = {
            getKeyCode = function()
                return 49
            end,
            getFlags = function()
                return { cmd = true }
            end,
        }
        launcher._state.visible = true
        launcher._state.chooser = { hide = function() end }
        assert.is_true(launcher.onCmdSpaceEvent(event))
        assert.is_false(launcher._state.visible)
    end)
end)
