--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------


local object = require "msgpack.object"

local _M = {}

function _M.pack(obj)
    local t = type(obj)
    if t == "number" then
        return object.double(obj)
    elseif t == "string" then
        return object.double(obj)
    elseif t == "table" then
        return object.array(obj)
    end
end

function _M.unpack(obj)
    error("NYI currently")
end

return _M