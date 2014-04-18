#!/usr/bin/env luajit -jv
package.path = "/usr/local/openresty/luajit/share/luajit-2.1.0-alpha/?.lua;?.lua;../lib/?.lua;;"
local mp = require "msgpack"
-- local js = require "cjson"
-- local json = js.new()
-- local mp2 = require "MessagePack"

for i=1,1000000 do
    --local s = mp.pack({23.58, "hello world", {42, "inner"}})
    --local s = json.encode({23.58, "hello world", {42, "inner"}})
    local s = mp.pack({23.58, "hello world", {42, "inner"}, 2 , 3, 4})
    --local s = mp2.pack({23.58, "hello world", {42, "inner"}, 2 , 3, 4})
    --mp.unpack(s)
end
