--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------

-- some NOTEs:
-- * for little endian CPU only.(bigendian should fix the string.reverse)
-- * double in lua should be 64bit, which is default mostly.

local ffi = require "ffi"
local bit = require "bit"
local spec = require "msgpack.spec"
local s_reverse = string.reverse
local s_sub = string.sub

local _M = {}


local double = ffi.new("double [1]")
local uint16 = ffi.new("uint16_t [1]")
local uint32 = ffi.new("uint32_t [1]")

---------------------------
-- Serialization related --
---------------------------

function _M.double(number)
    local head1 = string.char(spec.float64)
    double[0] = number
    local obj_str = s_reverse(ffi.string(double, 8))
    return head1 .. obj_str
end

function _M.string(str)
    local len = string.len(str)
    if len <= 31 then
        local head1 = string.char(spec.fixstr1 + len)
        return head1 .. str
    elseif len < 0xFF then
        local head1 = string.char(spec.str8)
        local head2 = string.char(len)
        return head1 .. head2 .. str
    elseif len < 0xFFFF then
        local head1 = string.char(spec.str16)
        local head2 = s_reverse(ffi.string(uint16(len), 2))
        return head1 .. head2 .. str
    elseif len < 0xFFFFFFFF then
        local head1 = string.char(spec.str32)
        local head2 = s_reverse(ffi.string(uint32(len), 4))
        return head1 .. head2 .. str
    end
end

function _M._encode_array(items, len, headers, ranges)
    -- @items: the string of array items
    if len <= 15 then
        local head1 = string.char(spec.fixarray1 + len)
        return head1 .. items
    elseif len < 0xFFFF then
        local head1 = string.char(spec.array16)
        uint16[0] = len
        local head2 = s_reverse(ffi.string(uint16, 2))
        return head1 .. head2 .. items
    elseif len < 0xFFFFFFFF then
        local head1 = string.char(spec.array32)
        uint32[0] = len
        local head2 = s_reverse(ffi.string(uint32, 4))
        return head1 .. head2 .. items
    end
end

function _M.array(arr)
    local childs = ""
    local t
    for i,v in ipairs(arr) do
        t = type(v)
        if t == "number" then
            childs = childs .. _M.double(v)
        elseif t == "string" then
            childs = childs .. _M.string(v)
        elseif t == "table" then
            childs = childs .. _M.array(v)
        end
    end
    return _M._encode_array(childs, #arr, headers, ranges)
end

return _M
