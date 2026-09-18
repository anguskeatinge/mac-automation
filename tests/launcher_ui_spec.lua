package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local ui = require("angus_scripts.launcher.ui")

describe("Launcher overlay UI", function()
    it("ships a complete overlay document", function()
        local html = ui.readHTML()
        assert.is_truthy(html)
        assert.is_truthy(html:find("launcherBridge", 1, true))
        assert.is_truthy(html:find('placeholder="Launch"', 1, true))
        assert.is_truthy(html:find("window.__setState", 1, true))
    end)

    it("encodes nested overlay state as JSON", function()
        local json = ui.jsonEncode({
            mode = "pins",
            resetQuery = true,
            items = {
                { name = 'He said "hi"', alias = "c" },
            },
        })
        assert.is_truthy(json:find('"mode":"pins"', 1, true))
        assert.is_truthy(json:find('"resetQuery":true', 1, true))
        assert.is_truthy(json:find('\\"hi\\"', 1, true))
        assert.is_truthy(json:find("^%[", json:find('"items":', 1, true) + 8))
    end)

    it("returns a stub overlay when webview is unavailable", function()
        local created = ui.create({
            onQuery = function() end,
        })
        assert.is_truthy(created.show)
        created:show({ mode = "pins", items = {} })
        created:hide()
        created:delete()
    end)
end)
