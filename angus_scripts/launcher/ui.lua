-- Minimal solid overlay for the Cmd+Space launcher (step 1: no glass/blur yet).

local hs = hs or require("tests.mocks.hs_mock")

local M = {}

local function moduleDir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    return src:match("^(.*)/[^/]+$") or "."
end

function M.readHTML()
    local path = moduleDir() .. "/overlay.html"
    local file = io.open(path, "r")
    if not file then
        return nil, path
    end
    local html = file:read("*a")
    file:close()
    return html, path
end

local function isArray(value)
    local n = #value
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > n then
            return false
        end
        count = count + 1
    end
    return count == n
end

function M.jsonEncode(value)
    local kind = type(value)
    if value == nil then
        return "null"
    end
    if kind == "number" then
        return tostring(value)
    end
    if kind == "boolean" then
        return value and "true" or "false"
    end
    if kind == "string" then
        return '"'
            .. value
                :gsub("\\", "\\\\")
                :gsub('"', '\\"')
                :gsub("\n", "\\n")
                :gsub("\r", "\\r")
                :gsub("\t", "\\t")
            .. '"'
    end
    if kind ~= "table" then
        return "null"
    end
    if isArray(value) then
        local parts = {}
        for i = 1, #value do
            parts[i] = M.jsonEncode(value[i])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for key, item in pairs(value) do
        table.insert(parts, M.jsonEncode(tostring(key)) .. ":" .. M.jsonEncode(item))
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local function screenFrame()
    if hs.screen and hs.screen.mainScreen then
        local screen = hs.screen.mainScreen()
        if screen and screen.fullFrame then
            return screen:fullFrame()
        end
        if screen and screen.frame then
            return screen:frame()
        end
    end
    return { x = 0, y = 0, w = 1440, h = 900 }
end

local function messageBody(message)
    if type(message) == "table" and message.body ~= nil then
        return message.body
    end
    return message
end

local function stubOverlay()
    return {
        show = function() end,
        update = function() end,
        hide = function() end,
        delete = function() end,
    }
end

local function push(self, state)
    if not self.webview or not self.webview.evaluateJavaScript then
        return
    end
    self.webview:evaluateJavaScript("window.__setState && window.__setState(" .. M.jsonEncode(state) .. ")")
end

function M.create(callbacks)
    callbacks = callbacks or {}
    if not hs.webview or not hs.webview.new or not hs.webview.usercontent then
        return stubOverlay()
    end

    local html, path = M.readHTML()
    if not html then
        print("[launcher] missing overlay at " .. tostring(path))
        return stubOverlay()
    end

    local ucc = hs.webview.usercontent.new("launcherBridge")
    local overlay = {
        webview = nil,
        usercontent = ucc,
        visible = false,
        pageReady = false,
        pending = nil,
    }

    ucc:setCallback(function(message)
        local body = messageBody(message)
        if type(body) ~= "table" then
            return
        end
        if body.type == "query" and callbacks.onQuery then
            callbacks.onQuery(body.query or "")
        elseif body.type == "select" and callbacks.onSelect then
            callbacks.onSelect(body.index)
        elseif body.type == "dismiss" and callbacks.onDismiss then
            callbacks.onDismiss()
        end
    end)

    local wv = hs.webview.new(screenFrame(), {
        javaScriptEnabled = true,
        developerExtrasEnabled = false,
        privateBrowsing = true,
    }, ucc)

    wv:transparent(true)
    wv:allowTextEntry(true)
    wv:windowStyle({ "borderless" })
    wv:shadow(false)
    if wv.allowNewWindows then
        wv:allowNewWindows(false)
    end
    if wv.darkMode then
        wv:darkMode(true)
    end
    if hs.drawing and hs.drawing.windowLevels and hs.drawing.windowLevels.modalPanel then
        wv:level(hs.drawing.windowLevels.modalPanel)
    end
    if wv.behaviorAsLabels then
        pcall(function()
            wv:behaviorAsLabels({ "moveToActiveSpace", "transient", "ignoresCycle" })
        end)
    end
    wv:html(html)
    wv:hide()

    if wv.navigationCallback then
        wv:navigationCallback(function(action)
            if action == "didFinishNavigation" or action == "didFinish" then
                overlay.pageReady = true
                if overlay.pending then
                    push(overlay, overlay.pending)
                    overlay.pending = nil
                end
                if overlay.visible and overlay.webview and overlay.webview.evaluateJavaScript then
                    overlay.webview:evaluateJavaScript("window.__focus && window.__focus()")
                end
            end
        end)
    end

    overlay.webview = wv

    function overlay:show(state)
        self.visible = true
        self.pending = state
        self.webview:frame(screenFrame())
        push(self, state)
        self.webview:show()
        self.webview:bringToFront(true)
        self.webview:evaluateJavaScript("window.__focus && window.__focus()")
        if hs.application and hs.application.get then
            local app = hs.application.get("Hammerspoon")
            if app and app.activate then
                app:activate()
            end
        end
    end

    function overlay:update(state)
        push(self, state)
    end

    function overlay:hide()
        self.visible = false
        if self.webview and self.webview.hide then
            self.webview:hide()
        end
    end

    function overlay:delete()
        if self.webview and self.webview.delete then
            self.webview:delete()
        end
        self.webview = nil
        self.usercontent = nil
        self.visible = false
        if _G._hammerspoon_launcher_refs == self then
            _G._hammerspoon_launcher_refs = nil
        end
    end

    _G._hammerspoon_launcher_refs = overlay
    return overlay
end

return M
