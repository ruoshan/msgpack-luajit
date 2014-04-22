--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------


local spec = require "msgpack.spec"
local encode = require "msgpack.encode"
local decode = require "msgpack.decode"

local _M = {}

function _M.pack(obj)
    local t = type(obj)
    if t == "number" then
        return encode.double(obj)
    elseif t == "string" then
        return encode.string(obj)
    elseif t == "table" then
        return encode.array(obj)
    end
end

function _M.unpack(str)
    return decode.decode(str, 1)
end

return _M
