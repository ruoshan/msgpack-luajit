--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------


local spec = require "msgpack.spec"
local object = require "msgpack.object"

local _M = {}

function _M.pack(obj)
    local t = type(obj)
    if t == "number" then
        return object.encode_double(obj)
    elseif t == "string" then
        return object.encode_string(obj)
    elseif t == "table" then
        return object.encode_array(obj)
    end
end

function _M.unpack(str)
    local head1 = string.byte(str)
    if object.is_double(head1) then
        return object.decode_double(str, 1)
    elseif object.is_string(head1) then
        return object.decode_string(str, 1)
    elseif object.is_array(head1) then
        return object.decode_array(str, 1)
    end
end

return _M
