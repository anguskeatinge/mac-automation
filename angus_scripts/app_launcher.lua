-- Cmd+Space app launcher with a custom glass overlay
-- Hard aliases beat fuzzy name matching so "t" / "te" is always iTerm, never Terminal.

local hs = hs or require("tests.mocks.hs_mock")
local overlay = require("angus_scripts.launcher.ui")

local M = {}

-- Typing any prefix of a stem resolves to that app (c/ch/chrome, t/term/iterm, s/slack).
-- minPrefix avoids collisions: "s" is Slack, Spotlight starts at "sp".
local chrome = { name = "Google Chrome", bundleID = "com.google.Chrome", pin = "c" }
local iterm = { name = "iTerm", bundleID = "com.googlecode.iterm2", pin = "t" }
local slack = { name = "Slack", bundleID = "com.tinyspeck.slackmacgap", pin = "s" }
local spotlight = { name = "Spotlight", action = "spotlight", bundleID = "com.apple.Spotlight", pin = "sp" }

M.pinnedAliases = { "t", "c", "s", "sp" }
M.shortNames = {
    ["Google Chrome"] = "Chrome",
}
M.skipBundleIDs = {
    ["org.hammerspoon.Hammerspoon"] = true,
}
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
    overlay = nil,
    hotkey = nil,
    tap = nil,
    watchers = {},
    apps = nil,
    visible = false,
    ignoreNextHotkey = false,
    lastItems = nil,
    iconURLCache = {},
    restoreApp = nil,
    query = "",
    openApps = nil,
    iconWarmIndex = 1,
    iconWarmTimer = nil,
    catalogTimer = nil,
    populateTimer = nil,
    cachedShortlist = nil,
    cachedOpen = nil,
    cachedRest = nil,
}

local function defaultDeps()
    return {
        imageFromAppBundle = function(bundleID)
            return hs.image.imageFromAppBundle(bundleID)
        end,
        launchOrFocusByBundleID = function(bundleID)
            return hs.application.launchOrFocusByBundleID(bundleID)
        end,
        launchOrFocusByName = function(name)
            return hs.application.launchOrFocus(name)
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
        createOverlay = function(callbacks)
            return overlay.create(callbacks)
        end,
        frontmostApp = function()
            if hs.application and hs.application.frontmostApplication then
                return hs.application.frontmostApplication()
            end
            return nil
        end,
        runningApplications = function()
            if hs.application and hs.application.runningApplications then
                return hs.application.runningApplications()
            end
            return {}
        end,
        collectCatalog = function()
            return M.collectApps()
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

function M.normalizeQuery(query)
    return (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

function M.resolveAlias(query)
    return M.aliases[M.normalizeQuery(query)]
end

local function isTerminal(app)
    return app.bundleID == M.terminalBundleID
end

-- Terminal is hidden for t/term so iTerm wins. Empty query and the full word still show it.
function M.allowsApp(app, query)
    if not isTerminal(app) then
        return true
    end
    local q = M.normalizeQuery(query)
    return q == "" or q == "terminal"
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
    -- Single letters are alias or prefix only. "t" must not match Spotlight.
    if #q < 2 then
        return 0
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

function M.matchesQuery(app, query)
    local q = M.normalizeQuery(query)
    if q == "" then
        return M.allowsApp(app, q)
    end
    return M.scoreApp(app, q) > 0
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

function M.shortlistItems()
    local items = {}
    local seen = {}
    for _, key in ipairs(M.pinnedAliases) do
        local pinned = M.aliases[key]
        local seenKey = pinned.bundleID or pinned.action
        if pinned and not seen[seenKey] then
            seen[seenKey] = true
            table.insert(items, {
                name = pinned.name,
                bundleID = pinned.bundleID,
                action = pinned.action,
                alias = key,
            })
        end
    end
    return items
end

function M.shortlistBundleIDs()
    local ids = {}
    for _, item in ipairs(M.shortlistItems()) do
        if item.bundleID then
            ids[item.bundleID] = true
        end
        if item.action then
            ids[item.action] = true
        end
    end
    return ids
end

local function sortByScoreThenName(items)
    table.sort(items, function(a, b)
        local as = a.score or 0
        local bs = b.score or 0
        if as == bs then
            return (a.name or "") < (b.name or "")
        end
        return as > bs
    end)
end

function M.groupApps(query, catalog, openApps)
    local q = M.normalizeQuery(query)
    local reserved = M.shortlistBundleIDs()

    local shortlist = {}
    for _, item in ipairs(M.shortlistItems()) do
        if M.matchesQuery(item, q) then
            table.insert(shortlist, item)
        end
    end

    local reservedNames = {}
    for _, item in ipairs(M.shortlistItems()) do
        reservedNames[(item.name or ""):lower()] = true
    end

    local openSeen = {}
    local open = {}
    for _, app in ipairs(openApps or {}) do
        local key = app.bundleID or app.path or app.name
        local nameKey = (app.name or ""):lower()
        if key and not reserved[key] and not reservedNames[nameKey] and not openSeen[key] and not M.skipBundleIDs[key] and M.matchesQuery(app, q) then
            table.insert(open, {
                name = app.name,
                bundleID = app.bundleID,
                path = app.path,
                alias = aliasForBundle(app.bundleID),
                score = q == "" and 0 or M.scoreApp(app, q),
            })
            openSeen[key] = true
            reservedNames[nameKey] = true
        end
    end
    sortByScoreThenName(open)

    local rest = {}
    if catalog then
        for _, app in ipairs(catalog) do
            local key = app.bundleID or app.path or app.name
            local nameKey = (app.name or ""):lower()
            if key and not reserved[key] and not reservedNames[nameKey] and not openSeen[key] and not M.skipBundleIDs[key] and M.matchesQuery(app, q) then
                table.insert(rest, {
                    name = app.name,
                    bundleID = app.bundleID,
                    path = app.path,
                    alias = aliasForBundle(app.bundleID),
                    score = q == "" and 0 or M.scoreApp(app, q),
                })
                openSeen[key] = true
            end
        end
        sortByScoreThenName(rest)
    end

    return {
        { id = "shortlist", title = "Shortlist", items = shortlist },
        { id = "open", title = "Open", items = open },
        { id = "rest", title = "Apps", items = rest },
    }
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
            table.insert(apps, {
                name = file:gsub("%.app$", ""),
                path = dir .. "/" .. file,
            })
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

local function appField(app, key)
    local value = app[key]
    if type(value) == "function" then
        return value(app)
    end
    return value
end

-- Dock / Cmd+Tab apps: regular GUI with a real window, not background agents.
function M.hasSidebarWindow(app)
    if type(app.allWindows) ~= "function" then
        return true
    end
    for _, win in ipairs(app:allWindows() or {}) do
        local standard = (not win.isStandard) or win:isStandard()
        if standard then
            return true
        end
    end
    return false
end

function M.collectOpenApps()
    local raw = M._deps.runningApplications and M._deps.runningApplications() or {}
    local apps = {}
    local seen = {}
    for _, app in ipairs(raw) do
        local name = appField(app, "name")
        local bundleID = appField(app, "bundleID")
        local kind = appField(app, "kind") or 0
        if kind == 0 and name and bundleID and not seen[bundleID] and not M.skipBundleIDs[bundleID] and M.hasSidebarWindow(app) then
            seen[bundleID] = true
            table.insert(apps, { name = name, bundleID = bundleID })
        end
    end
    table.sort(apps, function(a, b)
        return a.name < b.name
    end)
    return apps
end

function M.refreshOpenApps()
    M._state.openApps = M.collectOpenApps()
    return M._state.openApps
end

function M.displayName(name)
    return M.shortNames[name] or name
end

function M.iconURL(bundleID)
    local id = bundleID or "com.apple.Spotlight"
    local cache = M._state.iconURLCache
    if cache[id] ~= nil then
        return cache[id]
    end
    local url = ""
    local fetched, img = pcall(M._deps.imageFromAppBundle, id)
    if fetched and img then
        local ok, encoded = pcall(function()
            local src = img
            if img.copy then
                src = img:copy() or img
            end
            if src.setSize then
                src = src:setSize({ w = 72, h = 72 }) or src
            end
            if src.encodeAsURLString then
                return src:encodeAsURLString() or ""
            end
            return ""
        end)
        if ok and type(encoded) == "string" then
            url = encoded
        end
    end
    cache[id] = url
    return url
end

function M.cachedIconURL(bundleID)
    local id = bundleID or "com.apple.Spotlight"
    return M._state.iconURLCache[id] or ""
end

function M.toOverlayItems(ranked, opts)
    opts = opts or {}
    local eager = opts.eagerIcons
    if eager == nil then
        eager = true
    end
    local items = {}
    for _, item in ipairs(ranked or {}) do
        table.insert(items, {
            name = item.name,
            displayName = M.displayName(item.name),
            alias = item.alias,
            bundleID = item.bundleID,
            path = item.path,
            action = item.action,
            icon = eager and M.iconURL(item.bundleID) or "",
        })
    end
    return items
end

function M.overlayState(query, resetQuery, opts)
    opts = opts or {}
    M._state.query = query or ""
    local groups = M.groupApps(query, M._state.apps, M._state.openApps)
    local lastItems = {}
    local overlayGroups = {}
    for _, group in ipairs(groups) do
        local items = M.toOverlayItems(group.items, { eagerIcons = group.id == "shortlist" })
        table.insert(overlayGroups, {
            id = group.id,
            title = group.title,
            items = items,
        })
        for _, item in ipairs(items) do
            table.insert(lastItems, item)
        end
    end
    M._state.lastItems = lastItems
    if M.normalizeQuery(query) == "" then
        M._state.cachedShortlist = overlayGroups[1] and overlayGroups[1].items or nil
        M._state.cachedOpen = overlayGroups[2] and overlayGroups[2].items or nil
        M._state.cachedRest = overlayGroups[3] and overlayGroups[3].items or nil
    end
    return {
        query = query or "",
        groups = overlayGroups,
        catalogReady = M._state.apps ~= nil,
        resetQuery = resetQuery and true or false,
        keepSelection = opts.keepSelection and true or false,
    }
end

function M.instantState()
    local shortlist = M._state.cachedShortlist
    if not shortlist then
        shortlist = M.toOverlayItems(M.shortlistItems(), { eagerIcons = true })
        M._state.cachedShortlist = shortlist
    end
    local groups = {
        { id = "shortlist", title = "Shortlist", items = shortlist },
        { id = "open", title = "Open", items = M._state.cachedOpen or {} },
        { id = "rest", title = "Apps", items = M._state.cachedRest or {} },
    }
    local lastItems = {}
    for _, group in ipairs(groups) do
        for _, item in ipairs(group.items) do
            table.insert(lastItems, item)
        end
    end
    M._state.lastItems = lastItems
    M._state.query = ""
    return {
        query = "",
        groups = groups,
        catalogReady = M._state.apps ~= nil,
        resetQuery = true,
        keepSelection = false,
    }
end

function M.populateOpenAndRest()
    if not M._state.visible or not M._state.overlay then
        return
    end
    M.refreshOpenApps()
    M._state.overlay:update(M.overlayState(M._state.query, false, { keepSelection = true }))
end

function M.schedulePopulate()
    if M._state.populateTimer and M._state.populateTimer.stop then
        M._state.populateTimer:stop()
    end
    if hs.timer then
        M._state.populateTimer = hs.timer.doAfter(0, function()
            M._state.populateTimer = nil
            M.populateOpenAndRest()
        end)
        return
    end
    M.populateOpenAndRest()
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

function M.stopIconWarm()
    if M._state.iconWarmTimer and M._state.iconWarmTimer.stop then
        M._state.iconWarmTimer:stop()
    end
    M._state.iconWarmTimer = nil
end

function M.stopCatalogTimer()
    if M._state.catalogTimer and M._state.catalogTimer.stop then
        M._state.catalogTimer:stop()
    end
    M._state.catalogTimer = nil
end

function M.bundleIDForPath(path)
    if not path or not hs.application or not hs.application.infoForBundlePath then
        return nil
    end
    local ok, info = pcall(hs.application.infoForBundlePath, path)
    if ok and info and info.CFBundleIdentifier then
        return info.CFBundleIdentifier
    end
    return nil
end

function M.warmRestIcons()
    M.stopIconWarm()
    M._state.iconWarmIndex = 1
    local function step()
        local apps = M._state.apps or {}
        local n = 0
        while M._state.iconWarmIndex <= #apps and n < 12 do
            local app = apps[M._state.iconWarmIndex]
            if app and not app.bundleID and app.path then
                app.bundleID = M.bundleIDForPath(app.path)
            end
            if app and app.bundleID then
                M.iconURL(app.bundleID)
            end
            M._state.iconWarmIndex = M._state.iconWarmIndex + 1
            n = n + 1
        end
        if M._state.iconWarmIndex <= #apps and hs.timer then
            M._state.iconWarmTimer = hs.timer.doAfter(0.04, step)
        else
            M._state.iconWarmTimer = nil
        end
    end
    if hs.timer then
        M._state.iconWarmTimer = hs.timer.doAfter(0.04, step)
    end
end

function M.scheduleCatalogRefresh(delay)
    if M._state.catalogTimer then
        return
    end
    local wait = delay or 0.05
    if not hs.timer then
        M.refreshApps()
        return
    end
    M._state.catalogTimer = hs.timer.doAfter(wait, function()
        M._state.catalogTimer = nil
        M.refreshApps()
    end)
end

function M.refreshApps()
    local ok, apps = pcall(function()
        return M._deps.collectCatalog()
    end)
    if not ok then
        print("[launcher] catalog scan failed: " .. tostring(apps))
        M.scheduleCatalogRefresh(1)
        return nil
    end
    M._state.apps = apps or {}
    if M._state.visible and M._state.overlay and M._state.overlay.update then
        M._state.overlay:update(M.overlayState(M._state.query, false, { keepSelection = true }))
    else
        M.overlayState(M._state.query or "", false)
    end
    M.warmRestIcons()
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

function M.escapeKeyCode()
    if hs.keycodes and hs.keycodes.map and hs.keycodes.map.escape then
        return hs.keycodes.map.escape
    end
    return 53
end

function M.isEscape(event)
    if not event or not event.getKeyCode then
        return false
    end
    return event:getKeyCode() == M.escapeKeyCode()
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
    local bundleID = choice.bundleID
    if (not bundleID or bundleID == "") and choice.path then
        bundleID = M.bundleIDForPath(choice.path)
        choice.bundleID = bundleID
    end
    if bundleID and bundleID ~= "" then
        return M.launchOrFocus(bundleID)
    end
    if choice.name and M._deps.launchOrFocusByName then
        return M._deps.launchOrFocusByName(choice.name)
    end
    return false
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

function M.hide(restore)
    M._state.visible = false
    if M._state.overlay and M._state.overlay.hide then
        M._state.overlay:hide()
    end
    if restore and M._state.restoreApp and M._state.restoreApp.activate then
        M._state.restoreApp:activate()
    end
    M._state.restoreApp = nil
    return "hide"
end

function M.show()
    if not M._state.overlay then
        return "show"
    end
    M._state.restoreApp = M._deps.frontmostApp and M._deps.frontmostApp() or nil
    M._state.visible = true
    M._state.overlay:show(M.instantState())
    M.schedulePopulate()
    if M._state.apps == nil then
        M.scheduleCatalogRefresh(0.05)
    end
    return "show"
end

function M.toggle()
    if M._state.visible then
        return M.hide(true)
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
    if not M._state.visible then
        return false
    end
    if M.isEscape(event) then
        M.hide(true)
        return true
    end
    if not M.isCmdSpace(event) then
        return false
    end
    -- Overlay can also deliver this keypress to the hotkey. Ignore that
    -- same-tick callback so close does not bounce back open.
    M._state.ignoreNextHotkey = true
    M.hide(true)
    if hs.timer then
        hs.timer.doAfter(0, function()
            M._state.ignoreNextHotkey = false
        end)
    end
    return true
end

function M.start()
    if M._state.overlay then
        return M
    end

    M._state.iconURLCache = {}
    M._state.query = ""
    for _, item in ipairs(M.shortlistItems()) do
        M.iconURL(item.bundleID)
    end
    M._state.cachedShortlist = M.toOverlayItems(M.shortlistItems(), { eagerIcons = true })
    M._state.overlay = M._deps.createOverlay({
        onQuery = M.onQuery,
        onSelect = M.onSelectIndex,
        onDismiss = function()
            M.hide(true)
        end,
    })

    M._state.hotkey = hs.hotkey.bind({ "cmd" }, "space", M.onHotkey)

    local tap = M._deps.newEventTap(M.onCmdSpaceEvent)
    if tap and tap.start then
        tap:start()
        M._state.tap = tap
    end

    -- Directory listing only. Held on state so Hammerspoon GC cannot eat the timer.
    M.scheduleCatalogRefresh(0.05)

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
    M.stopIconWarm()
    M.stopCatalogTimer()
    if M._state.populateTimer and M._state.populateTimer.stop then
        M._state.populateTimer:stop()
    end
    M._state.populateTimer = nil
    M._state.cachedShortlist = nil
    M._state.cachedOpen = nil
    M._state.cachedRest = nil
    if M._state.overlay and M._state.overlay.delete then
        M._state.overlay:delete()
    end
    M._state.hotkey = nil
    M._state.tap = nil
    M._state.watchers = {}
    M._state.overlay = nil
    M._state.apps = nil
    M._state.openApps = nil
    M._state.visible = false
    M._state.ignoreNextHotkey = false
    M._state.lastItems = nil
    M._state.iconURLCache = {}
    M._state.restoreApp = nil
    M._state.query = ""
    M._state.iconWarmIndex = 1
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
        launchOrFocusByName = function()
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
        runningApplications = function()
            return {}
        end,
        collectCatalog = function()
            return {}
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
