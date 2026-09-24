-- Cmd+Space app launcher
-- Hard aliases beat fuzzy name matching so "t" / "te" is always iTerm, never Terminal.
-- uiMode: "chooser" = proven native UI; "overlay" = custom panel (built incrementally).

local hs = hs or require("tests.mocks.hs_mock")
local overlayUI = require("angus_scripts.launcher.ui")

local M = {}

-- Step 1 overlay blocked the whole screen and could not be dismissed.
-- Stay on native chooser until the custom panel is safe.
M.uiMode = "chooser"

-- Typing any prefix of a stem resolves to that app (c/ch/chrome, t/term/iterm, s/slack).
-- minPrefix avoids collisions: "s" is Slack, Spotlight starts at "sp".
local chrome = { name = "Google Chrome", bundleID = "com.google.Chrome", pin = "c" }
local iterm = { name = "iTerm", bundleID = "com.googlecode.iterm2", pin = "t" }
local slack = { name = "Slack", bundleID = "com.tinyspeck.slackmacgap", pin = "s" }
local spotlight = { name = "Spotlight", action = "spotlight", bundleID = "com.apple.Spotlight", pin = "sp" }

M.pinnedAliases = { "c", "t", "s", "sp" }
M.aliases = {}

local function addStem(target, word, minPrefix)
    for i = minPrefix or 1, #word do
        local key = word:sub(1, i)
        if not M.aliases[key] then
            M.aliases[key] = target
        end
    end
end

addStem(chrome, "chrome")
addStem(iterm, "term")
addStem(iterm, "iterm", 2)
addStem(slack, "slack")
addStem(spotlight, "spotlight", 2)

M.terminalBundleID = "com.apple.Terminal"

M.appDirs = {
    "/Applications",
    "/System/Applications",
    "/System/Applications/Utilities",
}

M._state = {
    chooser = nil,
    overlay = nil,
    hotkey = nil,
    tap = nil,
    dismissModal = nil,
    watchers = {},
    apps = nil,
    visible = false,
    ignoreNextHotkey = false,
    emptyChoices = nil,
    lastItems = nil,
    restoreApp = nil,
    iconCache = {},
}

local function defaultDeps()
    return {
        imageFromAppBundle = function(bundleID)
            return hs.image.imageFromAppBundle(bundleID)
        end,
        launchOrFocusByBundleID = function(bundleID)
            return hs.application.launchOrFocusByBundleID(bundleID)
        end,
        getApp = function(bundleID)
            return hs.application.get(bundleID)
        end,
        activateApp = function(bundleID)
            -- AppleScript activate is the reliable way to raise Chrome when it is already open.
            local ok = hs.osascript.applescript(string.format('tell application id "%s" to activate', bundleID))
            return ok and true or false
        end,
        openSpotlight = function()
            -- Real Spotlight overlay, rebound to Opt+Space so it does not fight Cmd+Space.
            hs.eventtap.keyStroke({ "alt" }, "space", 0)
        end,
        hideChooser = function(chooser)
            if chooser and chooser.hide then
                chooser:hide()
            end
        end,
        createOverlay = function(callbacks)
            return overlayUI.create(callbacks)
        end,
        frontmostApp = function()
            if hs.application and hs.application.frontmostApplication then
                return hs.application.frontmostApplication()
            end
            return nil
        end,
        pathWatcher = function(dir, fn)
            if hs.pathwatcher then
                return hs.pathwatcher.new(dir, fn)
            end
            return nil
        end,
        newEventTap = function(fn)
            if hs.eventtap and hs.eventtap.event then
                return hs.eventtap.new({ hs.eventtap.event.types.keyDown }, fn)
            end
            return nil
        end,
    }
end

M._deps = defaultDeps()

function M.usingOverlay()
    return M.uiMode == "overlay"
end

function M.normalizeQuery(query)
    return (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

function M.resolveAlias(query)
    return M.aliases[M.normalizeQuery(query)]
end

local function isTerminal(app)
    return app.bundleID == M.terminalBundleID
end

-- Terminal only appears if you type the full word. "t" / "te" / "term" stay iTerm.
function M.allowsApp(app, query)
    if isTerminal(app) then
        return M.normalizeQuery(query) == "terminal"
    end
    return true
end

function M.scoreApp(app, query)
    local q = M.normalizeQuery(query)
    if q == "" then
        return 0
    end
    if not M.allowsApp(app, q) then
        return 0
    end

    local alias = M.aliases[q]
    if alias and alias.bundleID == app.bundleID then
        return 1000
    end

    local name = (app.name or ""):lower()
    if name == q then
        return 900
    end
    if name:sub(1, #q) == q then
        return 800
    end
    if name:find(q, 1, true) then
        return 500
    end

    -- subsequence: "gc" does not match, but "ggl" can match "google chrome"
    local idx = 1
    for i = 1, #q do
        idx = name:find(q:sub(i, i), idx, true)
        if not idx then
            return 0
        end
        idx = idx + 1
    end
    return 100
end

local function aliasForBundle(bundleID)
    for _, alias in pairs(M.aliases) do
        if alias.bundleID == bundleID then
            return alias.pin
        end
    end
    return nil
end

function M.rankApps(apps, query)
    local q = M.normalizeQuery(query)
    local alias = M.resolveAlias(q)
    local ranked = {}

    if q == "" then
        local seen = {}
        for _, key in ipairs(M.pinnedAliases) do
            local pinned = M.aliases[key]
            local seenKey = pinned.bundleID or pinned.action
            if pinned and not seen[seenKey] then
                seen[seenKey] = true
                table.insert(ranked, {
                    name = pinned.name,
                    bundleID = pinned.bundleID,
                    action = pinned.action,
                    score = 1000,
                    alias = key,
                })
            end
        end
        return ranked
    end

    if alias then
        table.insert(ranked, {
            name = alias.name,
            bundleID = alias.bundleID,
            action = alias.action,
            score = 1000,
            alias = q,
        })
    end

    local seen = {}
    if alias then
        seen[alias.bundleID or alias.action] = true
    end

    local scored = {}
    for _, app in ipairs(apps or {}) do
        if not seen[app.bundleID] then
            local score = M.scoreApp(app, q)
            if score > 0 then
                table.insert(scored, {
                    name = app.name,
                    bundleID = app.bundleID,
                    score = score,
                    alias = aliasForBundle(app.bundleID),
                    action = nil,
                })
                seen[app.bundleID] = true
            end
        end
    end

    table.sort(scored, function(a, b)
        if a.score == b.score then
            return a.name < b.name
        end
        return a.score > b.score
    end)

    for _, item in ipairs(scored) do
        table.insert(ranked, item)
    end
    return ranked
end

local function collectAppsFromDir(dir, apps)
    if not hs.fs or not hs.fs.dir then
        return
    end
    -- hs.fs.dir throws on missing paths (e.g. ~/Applications); skip those dirs.
    local ok, iter, dirObj = pcall(hs.fs.dir, dir)
    if not ok or not iter then
        return
    end
    for file in iter, dirObj do
        if type(file) == "string" and file:match("%.app$") then
            local path = dir .. "/" .. file
            local infoOk, info = pcall(function()
                return hs.application.infoForBundlePath(path)
            end)
            if infoOk and info and info.CFBundleIdentifier then
                table.insert(apps, {
                    name = file:gsub("%.app$", ""),
                    bundleID = info.CFBundleIdentifier,
                    path = path,
                })
            end
        end
    end
end

function M.collectApps()
    local apps = {}
    local unpack = table.unpack or unpack
    local dirs = { unpack(M.appDirs) }
    local home = os.getenv("HOME")
    if home then
        table.insert(dirs, home .. "/Applications")
    end
    for _, dir in ipairs(dirs) do
        collectAppsFromDir(dir, apps)
    end
    return apps
end

function M.iconFor(bundleID)
    local id = bundleID or "com.apple.Spotlight"
    local cache = M._state.iconCache
    if cache[id] == nil then
        cache[id] = M._deps.imageFromAppBundle(id)
    end
    return cache[id]
end

function M.toChoices(ranked)
    local choices = {}
    for _, item in ipairs(ranked) do
        local subText = item.alias and ("alias: " .. item.alias) or nil
        table.insert(choices, {
            text = item.name,
            subText = subText,
            bundleID = item.bundleID,
            action = item.action,
            image = M.iconFor(item.bundleID),
        })
    end
    return choices
end

function M.displayName(name)
    if name == "Google Chrome" then
        return "Chrome"
    end
    return name
end

function M.toOverlayItems(ranked)
    local items = {}
    for _, item in ipairs(ranked or {}) do
        table.insert(items, {
            name = item.name,
            displayName = M.displayName(item.name),
            alias = item.alias,
            bundleID = item.bundleID,
            action = item.action,
        })
    end
    return items
end

function M.overlayState(query, resetQuery)
    local ranked = M.rankApps(M._state.apps, query)
    -- Keep the first paint light while proving the panel.
    if #ranked > 12 then
        local trimmed = {}
        for i = 1, 12 do
            trimmed[i] = ranked[i]
        end
        ranked = trimmed
    end
    local items = M.toOverlayItems(ranked)
    M._state.lastItems = items
    return {
        query = query or "",
        items = items,
        resetQuery = resetQuery and true or false,
    }
end

function M.appDirsToWatch()
    local unpack = table.unpack or unpack
    local dirs = { unpack(M.appDirs) }
    local home = os.getenv("HOME")
    if home then
        table.insert(dirs, home .. "/Applications")
    end
    return dirs
end

function M.refreshApps()
    local ok, apps = pcall(M.collectApps)
    if not ok then
        print("[launcher] catalog scan failed: " .. tostring(apps))
        return M._state.apps
    end
    M._state.apps = apps or {}
    return M._state.apps
end

function M.spaceKeyCode()
    if hs.keycodes and hs.keycodes.map then
        return hs.keycodes.map.space
    end
    return 49
end

function M.isCmdSpace(event)
    if not event or not event.getKeyCode then
        return false
    end
    if event:getKeyCode() ~= M.spaceKeyCode() then
        return false
    end
    local flags = event.getFlags and event:getFlags() or {}
    return flags.cmd and not flags.alt and not flags.ctrl and not flags.shift
end

function M.openSpotlight()
    M.hide()
    return M._deps.openSpotlight()
end

function M.runChoice(choice)
    if not choice then
        return false
    end
    if choice.action == "spotlight" then
        return M.openSpotlight()
    end
    return M.launchOrFocus(choice.bundleID)
end

function M.launchOrFocus(bundleID)
    if not bundleID then
        return false
    end

    M._deps.activateApp(bundleID)

    local app = M._deps.getApp(bundleID)
    if app then
        if app.unhide then
            app:unhide()
        end
        local target
        if app.allWindows then
            for _, win in ipairs(app:allWindows() or {}) do
                local standard = (not win.isStandard) or win:isStandard()
                local visible = (not win.isVisible) or win:isVisible()
                if standard and visible then
                    target = win
                    break
                end
            end
        end
        target = target or (app.mainWindow and app:mainWindow()) or (app.focusedWindow and app:focusedWindow())
        if target and target.focus then
            target:focus()
        end
        return true
    end

    return M._deps.launchOrFocusByBundleID(bundleID)
end

local function refreshChoices(query)
    if not M._state.chooser then
        return
    end
    local q = M.normalizeQuery(query)
    if q == "" and M._state.emptyChoices then
        M._state.chooser:choices(M._state.emptyChoices)
        return
    end
    M._state.chooser:choices(M.toChoices(M.rankApps(M._state.apps, query)))
end

function M.onQuery(query)
    if not M._state.overlay or not M._state.overlay.update then
        return
    end
    M._state.overlay:update(M.overlayState(query, false))
end

function M.onSelectIndex(index)
    local item = (M._state.lastItems or {})[index]
    M.hide()
    if not item then
        return false
    end
    return M.runChoice(item)
end

-- Cmd+Space to *open* the launcher is the always-on hotkey. This extra chord
-- only exists because the chooser/overlay can swallow that hotkey while it has
-- focus. Bind Cmd+Space itself (modal), not every keyDown.
function M.enterDismissChord()
    if M._state.dismissModal then
        if M._state.dismissModal.enter then
            M._state.dismissModal:enter()
        end
        return
    end
    if hs.hotkey and hs.hotkey.modal and hs.hotkey.modal.new then
        local modal = hs.hotkey.modal.new()
        modal:bind({ "cmd" }, "space", function()
            M.onCmdSpaceEvent({
                getKeyCode = function()
                    return M.spaceKeyCode()
                end,
                getFlags = function()
                    return { cmd = true }
                end,
            })
        end)
        M._state.dismissModal = modal
        modal:enter()
        return
    end
    if M._state.tap then
        if M._state.tap.start then
            M._state.tap:start()
        end
        return
    end
    local tap = M._deps.newEventTap(M.onCmdSpaceEvent)
    if tap and tap.start then
        tap:start()
        M._state.tap = tap
    end
end

function M.exitDismissChord()
    if M._state.dismissModal and M._state.dismissModal.exit then
        M._state.dismissModal:exit()
    end
    if M._state.tap and M._state.tap.stop then
        M._state.tap:stop()
    end
end

function M.hide()
    M._state.visible = false
    M.exitDismissChord()
    local previous = M._state.restoreApp
    M._state.restoreApp = nil
    if M._state.overlay and M._state.overlay.hide then
        M._state.overlay:hide()
    end
    if M._state.chooser then
        M._state.chooser:hide()
    end
    if previous and previous.activate then
        previous:activate()
    end
    return "hide"
end

function M.show()
    if M._state.overlay then
        M._state.restoreApp = M._deps.frontmostApp and M._deps.frontmostApp() or nil
        M._state.visible = true
        M._state.overlay:show(M.overlayState("", true))
        M.enterDismissChord()
        return "show"
    end
    if not M._state.chooser then
        return "show"
    end
    -- Never scan disk here. Empty query is pinned aliases only.
    M._state.chooser:query("")
    if M._state.emptyChoices then
        M._state.chooser:choices(M._state.emptyChoices)
    else
        refreshChoices("")
    end
    M._state.visible = true
    M._state.chooser:show()
    M.enterDismissChord()
    return "show"
end

function M.toggle()
    if M._state.visible then
        return M.hide()
    end
    return M.show()
end

function M.onHotkey()
    if M._state.ignoreNextHotkey then
        M._state.ignoreNextHotkey = false
        return
    end
    M.toggle()
end

function M.onCmdSpaceEvent(event)
    if not M._state.visible or not M.isCmdSpace(event) then
        return false
    end
    -- Panel can swallow the Hammerspoon hotkey. Consume Cmd+Space and close.
    M._state.ignoreNextHotkey = true
    M.hide()
    if hs.timer then
        hs.timer.doAfter(0.2, function()
            M._state.ignoreNextHotkey = false
        end)
    end
    return true
end

function M.start()
    if M._state.chooser or M._state.overlay then
        return M
    end

    M._state.iconCache = {}

    if M.usingOverlay() then
        M._state.overlay = M._deps.createOverlay({
            onQuery = M.onQuery,
            onSelect = M.onSelectIndex,
            onDismiss = function()
                M.hide()
            end,
        })
    else
        M._state.emptyChoices = M.toChoices(M.rankApps(nil, ""))
        M._state.chooser = hs.chooser.new(function(choice)
            M._state.visible = false
            M.exitDismissChord()
            if not choice then
                return
            end
            M.runChoice(choice)
        end)

        M._state.chooser:placeholderText("c chrome · t iTerm · s Slack · sp Spotlight")
        M._state.chooser:searchSubText(false)
        M._state.chooser:rows(6)
        M._state.chooser:width(24)
        M._state.chooser:choices(M._state.emptyChoices)
        M._state.chooser:queryChangedCallback(function(query)
            refreshChoices(query)
        end)
        if M._state.chooser.hideCallback then
            M._state.chooser:hideCallback(function()
                M._state.visible = false
                M.exitDismissChord()
            end)
        end
    end

    M._state.hotkey = hs.hotkey.bind({ "cmd" }, "space", M.onHotkey)

    -- Warm the app list after the window can already open.
    if hs.timer then
        hs.timer.doAfter(0, M.refreshApps)
    else
        M.refreshApps()
    end

    M._state.watchers = {}
    for _, dir in ipairs(M.appDirsToWatch()) do
        local exists = true
        if hs.fs and hs.fs.attributes then
            exists = hs.fs.attributes(dir) ~= nil
        end
        if exists then
            local watcher = M._deps.pathWatcher(dir, function()
                M.refreshApps()
            end)
            if watcher and watcher.start then
                watcher:start()
                table.insert(M._state.watchers, watcher)
            end
        end
    end

    return M
end

function M.stop()
    if M._state.hotkey and M._state.hotkey.delete then
        M._state.hotkey:delete()
    end
    M.exitDismissChord()
    if M._state.dismissModal and M._state.dismissModal.delete then
        M._state.dismissModal:delete()
    end
    M._state.dismissModal = nil
    for _, watcher in ipairs(M._state.watchers or {}) do
        if watcher.stop then
            watcher:stop()
        end
    end
    if M._state.chooser and M._state.chooser.delete then
        M._state.chooser:delete()
    end
    if M._state.overlay and M._state.overlay.delete then
        M._state.overlay:delete()
    end
    M._state.hotkey = nil
    M._state.tap = nil
    M._state.dismissModal = nil
    M._state.watchers = {}
    M._state.chooser = nil
    M._state.overlay = nil
    M._state.apps = nil
    M._state.visible = false
    M._state.ignoreNextHotkey = false
    M._state.emptyChoices = nil
    M._state.lastItems = nil
    M._state.restoreApp = nil
    M._state.iconCache = {}
end

function M.reset()
    M.stop()
    M.uiMode = "chooser"
    M._deps = {
        imageFromAppBundle = function()
            return nil
        end,
        launchOrFocusByBundleID = function()
            return true
        end,
        getApp = function()
            return nil
        end,
        activateApp = function()
            return true
        end,
        openSpotlight = function()
            return true
        end,
        hideChooser = function()
            return true
        end,
        createOverlay = function()
            return {
                show = function() end,
                update = function() end,
                hide = function() end,
                delete = function() end,
            }
        end,
        frontmostApp = function()
            return nil
        end,
        pathWatcher = function()
            return nil
        end,
        newEventTap = function()
            return nil
        end,
    }
end

return M
