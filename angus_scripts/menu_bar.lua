-- Menu Bar
-- Simple menu bar interface for quick access to window management and layouts

local M = {}

function M.setup(windowManager, devLayout)
    local menubar = hs.menubar.new()

    if menubar then
        menubar:setTitle("⌘")

        local function updateMenu()
            menubar:setMenu({
                { title = "Dev Layout", fn = devLayout.run },
                { title = "-" },
                { title = "Maximize", fn = windowManager.maximize },
                { title = "Layout Widths", menu = {
                    { title = "3/4 Width", fn = windowManager.threeQuarterWidth },
                    { title = "2/3 Width", fn = windowManager.twoThirdWidth },
                    { title = "1/2 Width", fn = windowManager.halfWidth },
                    { title = "1/3 Width", fn = windowManager.oneThirdWidth },
                    { title = "1/4 Width", fn = windowManager.oneQuarterWidth },
                }},
                { title = "Screen Control", menu = {
                    { title = "Move to Previous Screen (Q)", fn = windowManager.cycleScreenQ },
                    { title = "Move to Next Screen (E)", fn = windowManager.cycleScreenE },
                }},
                { title = "-" },
                { title = "Reload Config", fn = hs.reload },
            })
        end

        updateMenu()
    end

    return menubar
end

return M
