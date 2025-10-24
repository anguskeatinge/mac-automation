-- ~/.hammerspoon/init.lua
hs.console.clearConsole()
hs.alert.show("Hammerspoon config reloaded")

-- auto-reload when files change
-- hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()

-- import layouts
local devLayout = require("angus_scripts.dev_layout")
-- you could later add: local designLayout = require("windows.layout_design")

-- hotkeys
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", devLayout.run)
