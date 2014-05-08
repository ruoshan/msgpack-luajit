--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------

local ffi = require "ffi"
local memcopy = ffi.copy
local bit = require "bit"
local spec = require "msgpack.spec"
local s_reverse = string.reverse
local s_sub = string.sub
local s_byte = string.byte

local _M = {}


local double = ffi.new("union {double d; uint64_t i; uint8_t c[8];}")
local uint16 = ffi.new("uint16_t [1]")
local uint32 = ffi.new("uint32_t [1]")
local uint8array_t = ffi.typeof("uint8_t [?]")

-----------------------------
-- Deserialization related --
-----------------------------

function _M.is_array(head)
    return ((head >= spec.fixarray1 and
                 head <= spec.fixarray2) or
            head == spec.array16 or
            head == spec.array32)
end

function _M.is_string(head)
    return ((head >= spec.fixstr1 and
                 head <= spec.fixstr2) or
            head == spec.str8 or
            head == spec.str16 or
            head == spec.str32)
end

function _M.is_double(head)
    return head == spec.float64
end

function _M.double(cstr, offset)
    -- @return: (number, offset).
    memcopy(double.c, cstr + offset + 1, 8)
    double.i = bit.bswap(double.i) -- big-endian to little-endian
    return double.d, offset + 9
end

function _M.fixstr(cstr, offset)
    local len = cstr[offset] - spec.fixstr1
    offset = offset + 1
    return ffi.string(cstr + offset, len), len + offset
end

function _M.string8(cstr, offset)
    offset = offset + 1
    local len = cstr[offset]
    return ffi.string(cstr + offset, len), len + offset + 1
end

function _M.string16(str, offset)
    offset = offset + 1
    local len_2byte = s_reverse(s_sub(str, offset, offset + 1))
    memcopy(uint16, len_2byte, 2)
    len = uint16[0]
    return s_sub(str, offset + 2, len + offset + 1), len + offset + 2
end

function _M.string32(str, offset)
    offest = offset + 1
    local len_4byte = s_reverse(s_sub(str, offset, offset + 3))
    memcopy(uint32, len_4byte, 4)
    len = uint32[0]
    return s_sub(str, offset + 4, len + offset + 3), len + offset + 4
end

function _M.fixarray(cstr, offset)
    local nitem = cstr[offset] - spec.fixarray1
    local objs = {}
    local head
    offset = offset + 1
    for i=1,nitem do
        head = cstr[offset]
        objs[i], offset = _M.unpackers[head](cstr, offset)
    end
    return objs, offset
end

function _M.array16(str, offset)
    local len_2byte = s_reverse(s_sub(str, offset + 1, offset + 2))
    memcopy(uint16, len_2byte, 2)
    local nitem = uint16[0]
    local objs = {}
    local head
    offset = offset + 3
    for i=1,nitem do
        head = s_byte(str, offset)
        objs[i], offset = _M.unpackers[head](str, offset)
    end
    return objs, offset
end

function _M.array32(str, offset)
    local len_4byte = s_reverse(s_sub(str, offset + 1, offset + 4))
    local nitem = uint32()
    memcopy(nitem, len_4byte, 4)
    nitem = nitem[0]
    local objs = {}
    local head
    offset = offset + 5
    for i=1,nitem do
        head = s_byte(str, offset)
        objs[i], offset = _M.unpackers[head](str, offset)
    end
    return nitem, offset
end

function _M.reserved(str, offset)
    print("reserved header, error in packed string?")
end

_M.unpackers = setmetatable(
    {
        [spec.float64] = _M.double,
        [spec.str8]    = _M.string8,
        [spec.str16]   = _M.string16,
        [spec.str32]   = _M.string32,
        [spec.array16] = _M.array16,
        [spec.array32] = _M.array32
    },
    {
        __index = function (t, k)
            if k < spec["nil"] then
                if k <= spec.pfixint2 then
                    return 'pfixint' -- FIXME
                elseif k <= spec.fixmap2 then
                    return 'fixmap' -- FIXME
                elseif k <= spec.fixarray2 then
                    return _M.fixarray
                else
                    return _M.fixstr
                end
            elseif k >= spec.nfixint2 then
                return 'nfixint' -- FIXME
            else
                return _M.reserved
            end
        end
})

function _M.decode(str, offset)
    local head = s_byte(str, offset)
    local len = string.len(str)
    local cstring = uint8array_t(len)
    memcopy(cstring, str, len)
    return _M.unpackers[head](cstring, 0)
end

return _M
