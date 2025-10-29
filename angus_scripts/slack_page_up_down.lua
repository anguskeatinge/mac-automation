-- Create hotkeys once and enable/disable them
local pageUpHotkey = hs.hotkey.new({}, "pageup", function()
  hs.eventtap.keyStroke({"shift", "alt"}, "up")
end)

local pageDownHotkey = hs.hotkey.new({}, "pagedown", function()
  hs.eventtap.keyStroke({"shift", "alt"}, "down")
end)


-- Enable immediately if Slack is currently focused
if hs.application.frontmostApplication():name() == "Slack" then
  pageUpHotkey:enable()
  pageDownHotkey:enable()
else
  pageUpHotkey:disable()
  pageDownHotkey:disable()
end


-- Watch for application switches
 appWatcher = hs.application.watcher.new(function(appName, eventType, app)
  if eventType == hs.application.watcher.activated then
    if appName == "Slack" then
        pageUpHotkey:enable()
        pageDownHotkey:enable()
    else
      pageUpHotkey:disable()
      pageDownHotkey:disable()
    end
  end
end)

appWatcher:start()
