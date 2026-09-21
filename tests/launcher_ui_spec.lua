package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local ui = require("angus_scripts.launcher.ui")

describe("Launcher overlay UI", function()
    it("ships a solid step-1 overlay document", function()
        local html = ui.readHTML()
        assert.is_truthy(html)
        assert.is_truthy(html:find("launcherBridge", 1, true))
        assert.is_truthy(html:find("Step 1: solid card only", 1, true))
        assert.is_falsy(html:find("backdrop-filter", 1, true))
    end)

    it("encodes overlay state as JSON", function()
        local json = ui.jsonEncode({
            resetQuery = true,
            items = { { name = 'He said "hi"', alias = "c" } },
        })
        assert.is_truthy(json:find('"resetQuery":true', 1, true))
        assert.is_truthy(json:find('\\"hi\\"', 1, true))
    end)
end)
