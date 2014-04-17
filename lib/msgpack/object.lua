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

local _M = {}


local double = ffi.typeof("double [1]")
local byte2 = ffi.typeof("uint16_t [1]")
local byte4 = ffi.typeof("uint32_t [1]")

function _M.double(number)
    local head1 = string.char(spec.float64)
    local head2 = string.reverse(ffi.string(double(number), 8))
    return head1 .. head2
end

local function _family0135(obj_str, len, header)
    -- 0: length is stored in the header
    -- 1: length is stored in the next byte
    -- 2: length is stored in the next two bytes
    -- 3: length is stored in the next four bytes
    if len <= 31 then
        local head1 = string.char(header[1] + len)
        return head1 .. obj_str
    elseif len < 0xFF then
        local head1 = string.char(header[2])
        local head2 = string.char(n)
        return head1 .. head2 .. obj_str
    elseif len < 0xFFFF then
        local head1 = string.char(header[3])
        local head2 = string.reverse(ffi.string(byte2(len)))
        return head1 .. head2 .. obj_str
    elseif len < 0xFFFFFFFF then
        local head1 = string.char(header[4])
        local head2 = string.reverse(ffi.string(byte4(len)))
        return head1 .. head2 .. obj_str
    end
    return nil
end

function _M.string(str)
    local len = string.len(str)
    local header = {spec.fixstr, spec.str8, spec.str16, spec.str32}
    return _family0135(str, len, header)
end

function _M.array(arr)
    local len = #arr
    --NOTE: not spec for array8
    local header = {spec.fixarray, spec.array16, spec.array16, spec.array32}
    local childs = {}
    local t
    for _,v in ipairs(arr) do
        t = type(v)
        if t == "number" then
            childs[#childs + 1] = _M.double(v)
        elseif t == "string" then
            childs[#childs + 1] = _M.string(v)
        elseif t == "table" then
            childs[#childs + 1] = _M.array(v)
        end
    end
    return _family0135(table.concat(childs), len, header)
end

return _M
