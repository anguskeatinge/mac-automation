-- bind ctrl opt -> and <- for chrome and vscode
hs.hotkey.bind({"ctrl", "option"}, "right", function()
  local appname = hs.application.frontmostApplication():name()
  if appname == "Google Chrome" then
    hs.eventtap.keyStroke({"ctrl"}, "tab")
  end
  if appname == "Code" then
    hs.eventtap.keyStroke({"cmd", "shift"}, "]")
  end
end)

hs.hotkey.bind({"ctrl", "option"}, "left", function()
  local appname = hs.application.frontmostApplication():name()
  if appname == "Google Chrome" then
    hs.eventtap.keyStroke({"ctrl", "shift"}, "tab")
  end
  if appname == "Code" then
    hs.eventtap.keyStroke({"cmd", "shift"}, "[")
  end
end)
