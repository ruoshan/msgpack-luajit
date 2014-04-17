#!/usr/bin/env luajit -jv
package.path = "../lib/?.lua;./?.lua;;"
local mp = require "msgpack"
-- local mp2 = require "MessagePack"

for i=1,100000 do
    mp.pack({23.58, "hello world", {42, "inner"}})
end

-- for i,v in ipairs(mp2.unpack(mp.pack({23.58, "hello world", {42, "inner"}}))) do
--     print(i,v)
-- end
