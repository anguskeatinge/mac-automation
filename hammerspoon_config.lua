-- ~/.hammerspoon/init.lua
hs.console.clearConsole()
hs.alert.show("Hammerspoon config reloaded")

-- auto-reload when files change
-- hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()

-- import layouts
local devLayout = require("angus_scripts.dev_layout")
local windowManager = require("angus_scripts.window_manager")
local menuBar = require("angus_scripts.menu_bar")

-- hotkeys
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", devLayout.run)

-- initialize window manager
windowManager.bindHotkeys()

-- initialize menu bar
menuBar.setup(windowManager, devLayout)
