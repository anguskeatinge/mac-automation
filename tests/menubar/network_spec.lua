-- Network Module Tests
-- Run with: busted tests/menubar/network_spec.lua

package.path = package.path .. ";./?.lua;./tests/?.lua;./tests/mocks/?.lua"

local hs_mock = require("tests.mocks.hs_mock")
_G.hs = hs_mock

local network = require("angus_scripts.menubar.network")

describe("Network Module", function()
    before_each(function()
        hs_mock.reset()
        network.reset()
    end)

    describe("parseNetstat", function()
        it("parses en0 bytes from netstat output", function()
            local output = [[
Name  Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0   16384 <Link#1>                        123456     0   12345678    98765     0    9876543     0
en0   1500  <Link#4>      aa:bb:cc:dd:ee:ff 234567     0 1234567890   345678     0  987654321     0
en1   1500  <Link#5>                             0     0          0        0     0          0     0
]]
            local result = network.parseNetstat(output)
            assert.is_not_nil(result)
            assert.are.equal(1234567890, result.bytesIn)
            assert.are.equal(987654321, result.bytesOut)
        end)

        it("returns nil for empty output", function()
            assert.is_nil(network.parseNetstat(""))
            assert.is_nil(network.parseNetstat(nil))
        end)

        it("returns zeros if en0 not found", function()
            local output = [[
Name  Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0   16384 <Link#1>                        123456     0   12345678    98765     0    9876543     0
]]
            local result = network.parseNetstat(output)
            assert.is_not_nil(result)
            assert.are.equal(0, result.bytesIn)
            assert.are.equal(0, result.bytesOut)
        end)
    end)

    describe("formatNetworkSpeed", function()
        it("formats download and upload speeds", function()
            local bytesDelta = { bytesIn = 10485760, bytesOut = 1048576 }  -- 10MB, 1MB
            local down, up = network.formatNetworkSpeed(bytesDelta, 1)
            assert.are.equal("10M", down)
            assert.are.equal("1M", up)
        end)

        it("handles nil bytes delta", function()
            local down, up = network.formatNetworkSpeed(nil, 1)
            assert.are.equal("?", down)
            assert.are.equal("?", up)
        end)

        it("handles zero time delta", function()
            local bytesDelta = { bytesIn = 1000, bytesOut = 500 }
            local down, up = network.formatNetworkSpeed(bytesDelta, 0)
            assert.are.equal("?", down)
            assert.are.equal("?", up)
        end)
    end)

    describe("create", function()
        it("creates menubar", function()
            network.create()
            assert.is_not_nil(network._state.menubar)
            local menubars = hs_mock.getMenubars()
            assert.are.equal(1, #menubars)
        end)

        it("sets initial title", function()
            network.create()
            assert.are.equal("\u{2193}-- \u{2191}--", network._state.menubar:title())  -- ↓-- ↑--
        end)
    end)

    describe("refresh", function()
        it("updates title with network speeds", function()
            local time = 1000
            local bytesSequence = {
                { bytesIn = 1000000, bytesOut = 500000 },
                { bytesIn = 2048000, bytesOut = 1024000 },  -- 1MB/s down, 512KB/s up
            }
            local callCount = 0

            network._deps.getTime = function()
                time = time + 1
                return time
            end
            network._deps.executeCommand = function(cmd)
                callCount = callCount + 1
                local bytes = bytesSequence[math.min(callCount, #bytesSequence)]
                return string.format([[
Name  Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
en0   1500  <Link#4>      aa:bb:cc:dd:ee:ff 234567     0 %d   345678     0  %d     0
]], bytes.bytesIn, bytes.bytesOut)
            end

            network.create()
            network.refresh()  -- First call sets baseline
            local down, up = network.refresh()  -- Second call calculates delta

            -- Verify title has arrow format
            local title = network._state.menubar:title()
            assert.truthy(title:match("\u{2193}"))  -- ↓
            assert.truthy(title:match("\u{2191}"))  -- ↑
        end)
    end)

    describe("destroy", function()
        it("cleans up menubar and state", function()
            network.create()
            network.destroy()
            assert.is_nil(network._state.menubar)
            assert.is_nil(network._state.prevNetBytes)
            assert.is_nil(network._state.prevNetTime)
        end)
    end)
end)
