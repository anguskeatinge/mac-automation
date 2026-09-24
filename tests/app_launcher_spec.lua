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

    it("skips missing application directories when scanning the catalog", function()
        hs.fs = hs.fs or {}
        hs.application = hs.application or {}
        hs.fs.dir = function(dir)
            if dir:find((os.getenv("HOME") or "") .. "/Applications", 1, true) == 1 then
                error("cannot open " .. dir .. ": No such file or directory")
            end
            local files = { "Safari.app", ".", ".." }
            local i = 0
            return function()
                i = i + 1
                return files[i]
            end
        end
        hs.application.infoForBundlePath = function(path)
            if path:match("Safari%.app$") then
                return { CFBundleIdentifier = "com.apple.Safari" }
            end
            return nil
        end
        launcher.appDirs = { "/Applications" }
        local apps = launcher.collectApps()
        assert.are.equal(1, #apps)
        assert.are.equal("Safari", apps[1].name)
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

    it("builds overlay items without icons in step 1", function()
        local items = launcher.toOverlayItems({
            { name = "Google Chrome", bundleID = "com.google.Chrome", alias = "c" },
        })
        assert.are.equal("Chrome", items[1].displayName)
        assert.is_nil(items[1].icon)
    end)

    it("starts the overlay UI when uiMode is overlay", function()
        local created = false
        launcher.uiMode = "overlay"
        launcher._deps.createOverlay = function(callbacks)
            created = true
            assert.is_truthy(callbacks.onQuery)
            assert.is_truthy(callbacks.onSelect)
            assert.is_truthy(callbacks.onDismiss)
            return {
                show = function() end,
                update = function() end,
                hide = function() end,
                delete = function() end,
            }
        end
        launcher.start()
        assert.is_true(created)
        assert.is_truthy(launcher._state.overlay)
        assert.is_nil(launcher._state.chooser)
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

    it("does not install a global keyDown tap at start", function()
        local taps = 0
        launcher._deps.newEventTap = function()
            taps = taps + 1
            return {
                start = function() end,
                stop = function() end,
            }
        end
        hs.chooser = {
            new = function()
                local chooser = {}
                function chooser:placeholderText() return self end
                function chooser:searchSubText() return self end
                function chooser:rows() return self end
                function chooser:width() return self end
                function chooser:choices() return self end
                function chooser:queryChangedCallback() return self end
                function chooser:hideCallback() return self end
                function chooser:query() return self end
                function chooser:show() return self end
                function chooser:hide() return self end
                function chooser:delete() return self end
                return chooser
            end,
        }
        launcher.start()
        assert.are.equal(0, taps)
        assert.is_true(#hs_mock.getHotkeys() >= 1)
    end)

    it("enables a cmd-space dismiss modal only while the chooser is showing", function()
        launcher._state.emptyChoices = {}
        launcher._state.chooser = {
            hide = function() end,
            show = function() end,
            query = function() end,
            choices = function() end,
        }
        launcher.show()
        assert.is_not_nil(launcher._state.dismissModal)
        assert.is_true(launcher._state.dismissModal._entered)
        launcher.hide()
        assert.is_false(launcher._state.dismissModal._entered)
    end)
end)
