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

    it("shows pinned iTerm, Chrome, Slack, and Spotlight when the query is empty", function()
        local ranked = launcher.rankApps(apps, "")
        assert.are.equal(4, #ranked)
        assert.are.equal("iTerm", ranked[1].name)
        assert.are.equal("Google Chrome", ranked[2].name)
        assert.are.equal("Slack", ranked[3].name)
        assert.are.equal("Spotlight", ranked[4].name)
        assert.are.equal("spotlight", ranked[4].action)
    end)

    it("maps sp to Spotlight", function()
        local ranked = launcher.rankApps(apps, "sp")
        assert.are.equal("Spotlight", ranked[1].name)
        assert.are.equal("spotlight", ranked[1].action)
    end)

    it("shortens Google Chrome to Chrome on the pin tiles", function()
        assert.are.equal("Chrome", launcher.displayName("Google Chrome"))
        assert.are.equal("iTerm", launcher.displayName("iTerm"))
    end)

    it("builds overlay items with aliases and short names", function()
        local items = launcher.toOverlayItems(launcher.rankApps(apps, ""))
        assert.are.equal(4, #items)
        assert.are.equal("iTerm", items[1].displayName)
        assert.are.equal("t", items[1].alias)
        assert.are.equal("spotlight", items[4].action)
    end)

    it("groups shortlist, then open apps, then the rest", function()
        local groups = launcher.groupApps("", apps, {
            { name = "Safari", bundleID = "com.apple.Safari" },
            { name = "iTerm", bundleID = "com.googlecode.iterm2" },
        })
        assert.are.equal("iTerm", groups[1].items[1].name)
        assert.are.equal("Google Chrome", groups[1].items[2].name)
        assert.are.equal("Slack", groups[1].items[3].name)
        assert.are.equal("Spotlight", groups[1].items[4].name)
        assert.are.equal("Safari", groups[2].items[1].name)
        for _, item in ipairs(groups[2].items) do
            assert.are_not.equal("com.googlecode.iterm2", item.bundleID)
        end
        assert.are.equal("Chess", groups[3].items[1].name)
        local restIds = {}
        for _, item in ipairs(groups[3].items) do
            restIds[item.bundleID] = true
        end
        assert.is_nil(restIds["com.apple.Safari"])
        assert.is_nil(restIds["com.google.Chrome"])
        assert.is_truthy(restIds["com.apple.Terminal"])
    end)

    it("filters every group as you type and hides Terminal for t", function()
        local groups = launcher.groupApps("t", apps, {
            { name = "TextEdit", bundleID = "com.apple.TextEdit" },
            { name = "Safari", bundleID = "com.apple.Safari" },
        })
        assert.are.equal(1, #groups[1].items)
        assert.are.equal("iTerm", groups[1].items[1].name)
        assert.are.equal("TextEdit", groups[2].items[1].name)
        for _, item in ipairs(groups[3].items) do
            assert.are_not.equal("com.apple.Terminal", item.bundleID)
        end
        assert.are.equal("Telegram", groups[3].items[1].name)
    end)

    it("only treats Dock-level apps with a real window as open", function()
        local function mockApp(name, bundleID, kind, windows)
            return {
                name = function()
                    return name
                end,
                bundleID = function()
                    return bundleID
                end,
                kind = function()
                    return kind
                end,
                allWindows = function()
                    return windows
                end,
            }
        end
        local standard = {
            isStandard = function()
                return true
            end,
        }
        local palette = {
            isStandard = function()
                return false
            end,
        }
        launcher._deps.runningApplications = function()
            return {
                mockApp("Safari", "com.apple.Safari", 0, { standard }),
                mockApp("Hidden Helper", "com.example.helper", 1, { standard }),
                mockApp("News", "com.apple.news", 0, {}),
                mockApp("Palette Only", "com.example.palette", 0, { palette }),
                mockApp("Notes", "com.apple.Notes", 0, { palette, standard }),
            }
        end
        local open = launcher.collectOpenApps()
        assert.are.equal(2, #open)
        assert.are.equal("Notes", open[1].name)
        assert.are.equal("Safari", open[2].name)
    end)

    it("always sends three overlay sections", function()
        local state = launcher.overlayState("", true)
        assert.are.equal(3, #state.groups)
        assert.are.equal("shortlist", state.groups[1].id)
        assert.are.equal("open", state.groups[2].id)
        assert.are.equal("rest", state.groups[3].id)
    end)

    it("keeps an empty Apps group until the catalog cache is ready", function()
        local groups = launcher.groupApps("", nil, {
            { name = "Safari", bundleID = "com.apple.Safari" },
        })
        assert.are.equal(3, #groups)
        assert.are.equal(4, #groups[1].items)
        assert.are.equal(1, #groups[2].items)
        assert.are.equal("Apps", groups[3].title)
        assert.are.equal(0, #groups[3].items)
    end)

    it("opens instantly with the shortlist and fills open apps after", function()
        local shown = nil
        local updated = nil
        launcher._deps.runningApplications = function()
            return { { name = "Safari", bundleID = "com.apple.Safari" } }
        end
        launcher._state.overlay = {
            show = function(_, state)
                shown = state
            end,
            hide = function() end,
            update = function(_, state)
                updated = state
            end,
        }
        assert.are.equal("show", launcher.show())
        assert.is_true(shown.resetQuery)
        assert.is_false(shown.catalogReady)
        assert.are.equal("Shortlist", shown.groups[1].title)
        assert.are.equal("iTerm", shown.groups[1].items[1].name)
        assert.are.equal("Chrome", shown.groups[1].items[2].displayName)
        assert.are.equal(0, #shown.groups[2].items)
        assert.are.equal(3, #shown.groups)
        launcher.populateOpenAndRest()
        assert.are.equal("Safari", updated.groups[2].items[1].name)
        assert.are.equal("Apps", updated.groups[3].title)
    end)

    it("does not send icon payloads for the Apps section", function()
        launcher._state.iconURLCache["com.apple.TextEdit"] = "data:image/png;base64,xxx"
        local items = launcher.toOverlayItems({
            { name = "TextEdit", bundleID = "com.apple.TextEdit" },
        }, { eagerIcons = false })
        assert.are.equal("", items[1].icon)
    end)

    it("filters overlay groups while typing", function()
        local updated = nil
        launcher._state.apps = apps
        launcher._state.openApps = { { name = "Safari", bundleID = "com.apple.Safari" } }
        launcher._state.overlay = {
            update = function(_, state)
                updated = state
            end,
        }
        launcher.onQuery("s")
        assert.is_false(updated.resetQuery)
        assert.are.equal("Slack", updated.groups[1].items[1].name)
        assert.are.equal("Safari", updated.groups[2].items[1].name)
        assert.is_true(updated.catalogReady)
    end)

    it("fills in the rest after the catalog cache lands", function()
        local updated = nil
        launcher._state.visible = true
        launcher._state.query = ""
        launcher._state.openApps = {}
        launcher._state.overlay = {
            update = function(_, state)
                updated = state
            end,
        }
        launcher._deps.runningApplications = function()
            return {}
        end
        local collected = false
        launcher._deps.collectCatalog = function()
            collected = true
            return apps
        end
        launcher.refreshApps()
        assert.is_true(collected)
        assert.is_true(updated.keepSelection)
        local titles = {}
        for _, group in ipairs(updated.groups) do
            titles[group.title] = true
        end
        assert.is_truthy(titles.Apps)
    end)

    it("selects Spotlight from the pin row", function()
        local opened = false
        launcher._deps.openSpotlight = function()
            opened = true
            return true
        end
        launcher._state.lastItems = {
            { name = "Spotlight", action = "spotlight" },
        }
        launcher._state.overlay = { hide = function() end }
        assert.is_true(launcher.onSelectIndex(1))
        assert.is_true(opened)
        assert.is_false(launcher._state.visible)
    end)

    it("toggles closed when already visible", function()
        local hidden = false
        local shown = false
        launcher._state.visible = true
        launcher._state.overlay = {
            hide = function()
                hidden = true
            end,
            show = function()
                shown = true
            end,
            update = function() end,
        }
        assert.are.equal("hide", launcher.toggle())
        assert.is_true(hidden)
        assert.is_false(shown)
        assert.is_false(launcher._state.visible)
    end)

    it("toggles open when hidden", function()
        local shown = false
        launcher._state.visible = false
        launcher._state.overlay = {
            hide = function() end,
            show = function()
                shown = true
            end,
            update = function() end,
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
        launcher._state.overlay = { hide = function() end }
        assert.is_true(launcher.onCmdSpaceEvent(event))
        assert.is_false(launcher._state.visible)
    end)

    it("swallows the close chord's hotkey but not the next open", function()
        local event = {
            getKeyCode = function()
                return 49
            end,
            getFlags = function()
                return { cmd = true }
            end,
        }
        launcher._state.visible = true
        launcher._state.overlay = {
            hide = function() end,
            show = function() end,
            update = function() end,
        }
        assert.is_true(launcher.onCmdSpaceEvent(event))
        assert.is_false(launcher._state.visible)
        launcher.onHotkey()
        assert.is_false(launcher._state.visible)
        for _, timer in ipairs(hs_mock.getTimers()) do
            timer:fire()
        end
        launcher.onHotkey()
        assert.is_true(launcher._state.visible)
    end)

    it("creates an overlay on start", function()
        local created = false
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
    end)

    it("treats escape as dismiss while open", function()
        local event = {
            getKeyCode = function()
                return 53
            end,
            getFlags = function()
                return {}
            end,
        }
        launcher._state.visible = true
        launcher._state.overlay = { hide = function() end }
        assert.is_true(launcher.onCmdSpaceEvent(event))
        assert.is_false(launcher._state.visible)
    end)
end)
