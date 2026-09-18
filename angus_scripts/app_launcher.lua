-- Minimal Cmd+Space app launcher
-- Hard aliases beat fuzzy name matching so "te" is always iTerm, never Terminal.

local hs = hs or require("tests.mocks.hs_mock")

local M = {}

M.aliases = {
    ch = { name = "Google Chrome", bundleID = "com.google.Chrome" },
    chr = { name = "Google Chrome", bundleID = "com.google.Chrome" },
    chrome = { name = "Google Chrome", bundleID = "com.google.Chrome" },
    te = { name = "iTerm", bundleID = "com.googlecode.iterm2" },
    it = { name = "iTerm", bundleID = "com.googlecode.iterm2" },
    term = { name = "iTerm", bundleID = "com.googlecode.iterm2" },
    iterm = { name = "iTerm", bundleID = "com.googlecode.iterm2" },
    sp = { name = "Spotlight", action = "spotlight", bundleID = "com.apple.Spotlight" },
    spotlight = { name = "Spotlight", action = "spotlight", bundleID = "com.apple.Spotlight" },
}

M.terminalBundleID = "com.apple.Terminal"

M.appDirs = {
    "/Applications",
    "/System/Applications",
    "/System/Applications/Utilities",
}

M._state = {
    chooser = nil,
    hotkey = nil,
    tap = nil,
    watchers = {},
    apps = nil,
    visible = false,
    ignoreNextHotkey = false,
    emptyChoices = nil,
    iconCache = {},
}

M._deps = {
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

function M.normalizeQuery(query)
    return (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

function M.resolveAlias(query)
    return M.aliases[M.normalizeQuery(query)]
end

local function isTerminal(app)
    return app.bundleID == M.terminalBundleID
end

-- Terminal only appears if you type the full word. "te" / "term" stay iTerm.
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
    for key, alias in pairs(M.aliases) do
        if alias.bundleID == bundleID then
            return key
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
        for _, key in ipairs({ "ch", "te", "sp" }) do
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
    local iter, dirObj = hs.fs.dir(dir)
    if not iter then
        return
    end
    for file in iter, dirObj do
        if type(file) == "string" and file:match("%.app$") then
            local path = dir .. "/" .. file
            local info = hs.application.infoForBundlePath(path)
            if info and info.CFBundleIdentifier then
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
    M._state.apps = M.collectApps()
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
    M._deps.hideChooser(M._state.chooser)
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

function M.hide()
    M._state.visible = false
    if M._state.chooser then
        M._state.chooser:hide()
    end
    return "hide"
end

function M.show()
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
    -- Chooser can swallow the Hammerspoon hotkey. Consume Cmd+Space and close.
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
    if M._state.chooser then
        return M
    end

    M._state.iconCache = {}
    M._state.emptyChoices = M.toChoices(M.rankApps(nil, ""))
    M._state.chooser = hs.chooser.new(function(choice)
        M._state.visible = false
        if not choice then
            return
        end
        M.runChoice(choice)
    end)

    M._state.chooser:placeholderText("ch chrome · te iTerm · sp Spotlight")
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
        end)
    end

    M._state.hotkey = hs.hotkey.bind({ "cmd" }, "space", M.onHotkey)

    local tap = M._deps.newEventTap(M.onCmdSpaceEvent)
    if tap and tap.start then
        tap:start()
        M._state.tap = tap
    end

    -- Warm the app list after the window can already open.
    if hs.timer then
        hs.timer.doAfter(0, M.refreshApps)
    else
        M.refreshApps()
    end

    M._state.watchers = {}
    for _, dir in ipairs(M.appDirsToWatch()) do
        local watcher = M._deps.pathWatcher(dir, function()
            M.refreshApps()
        end)
        if watcher and watcher.start then
            watcher:start()
            table.insert(M._state.watchers, watcher)
        end
    end

    return M
end

function M.stop()
    if M._state.hotkey and M._state.hotkey.delete then
        M._state.hotkey:delete()
    end
    if M._state.tap and M._state.tap.stop then
        M._state.tap:stop()
    end
    for _, watcher in ipairs(M._state.watchers or {}) do
        if watcher.stop then
            watcher:stop()
        end
    end
    if M._state.chooser and M._state.chooser.delete then
        M._state.chooser:delete()
    end
    M._state.hotkey = nil
    M._state.tap = nil
    M._state.watchers = {}
    M._state.chooser = nil
    M._state.apps = nil
    M._state.visible = false
    M._state.ignoreNextHotkey = false
    M._state.emptyChoices = nil
    M._state.iconCache = {}
end

function M.reset()
    M.stop()
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
        pathWatcher = function()
            return nil
        end,
        newEventTap = function()
            return nil
        end,
    }
end

return M
