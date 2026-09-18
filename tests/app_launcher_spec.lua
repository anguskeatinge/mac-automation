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
    { name = "Slack", bundleID = "com.tinyspeck.slackmacgap" },
    { name = "Safari", bundleID = "com.apple.Safari" },
}

describe("App launcher", function()
    before_each(function()
        hs_mock.reset()
        launcher.reset()
    end)

    it("maps every Chrome prefix from c through chrome", function()
        for _, query in ipairs({ "c", "C", "ch", "chr", "chro", "chrom", "chrome" }) do
            local alias = launcher.resolveAlias(query)
            assert.are.equal("com.google.Chrome", alias.bundleID)
        end
    end)

    it("maps every iTerm prefix from t through term and iterm", function()
        for _, query in ipairs({ "t", "TE", "ter", "term", "it", "ite", "iter", "iterm" }) do
            local alias = launcher.resolveAlias(query)
            assert.are.equal("com.googlecode.iterm2", alias.bundleID)
        end
    end)

    it("maps every Slack prefix from s through slack", function()
        for _, query in ipairs({ "s", "sl", "sla", "slac", "slack" }) do
            local alias = launcher.resolveAlias(query)
            assert.are.equal("com.tinyspeck.slackmacgap", alias.bundleID)
        end
    end)

    it("does not steal i or iTerm-adjacent single letters for other apps", function()
        assert.is_nil(launcher.resolveAlias("i"))
    end)

    it("puts Chrome first for c even when Chess exists", function()
        local ranked = launcher.rankApps(apps, "c")
        assert.are.equal("Google Chrome", ranked[1].name)
        assert.are.equal(1000, ranked[1].score)
    end)

    it("puts iTerm first for t and hides Terminal", function()
        local ranked = launcher.rankApps(apps, "t")
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

    it("puts Slack first for s instead of Safari or Spotlight", function()
        local ranked = launcher.rankApps(apps, "s")
        assert.are.equal("Slack", ranked[1].name)
        assert.are.equal(1000, ranked[1].score)
        assert.are_not.equal("spotlight", ranked[1].action)
    end)

    it("shows pinned Chrome, iTerm, Slack, and Spotlight when the query is empty", function()
        local ranked = launcher.rankApps(apps, "")
        assert.are.equal(4, #ranked)
        assert.are.equal("Google Chrome", ranked[1].name)
        assert.are.equal("iTerm", ranked[2].name)
        assert.are.equal("Slack", ranked[3].name)
        assert.are.equal("Spotlight", ranked[4].name)
        assert.are.equal("spotlight", ranked[4].action)
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
