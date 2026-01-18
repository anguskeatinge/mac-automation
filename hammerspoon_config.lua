-- ~/.hammerspoon/init.lua
hs.console.clearConsole()
hs.alert.show("Hammerspoon config reloaded")

-- hotkeys
devLayout = require("angus_scripts.dev_layout")
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", devLayout.run)

-- initialize window manager
windowManager = require("angus_scripts.window_manager")
windowManager.bindHotkeys()

slackKeyAppWatcher = require("angus_scripts.slack_page_up_down")

require("angus_scripts.vscode_chrome_ctrl_opt_L_R")

-- Menu bar stats (CPU, RAM, Network, Battery, Pomodoro, Clipboard)
menubar = require("angus_scripts.menubar")
menubar.start()
