--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------

local ffi = require "ffi"
local bit = require "bit"
local spec = require "msgpack.spec"
local s_reverse = string.reverse
local s_sub = string.sub

local floor = require'math'.floor
local frexp = require'math'.frexp
local ldexp = require'math'.ldexp
local huge = require'math'.huge

local _M = {}


local double = ffi.typeof("double [1]")
local uint16 = ffi.typeof("uint16_t [1]")
local uint32 = ffi.typeof("uint32_t [1]")

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

function _M.double(str, offset)
    -- FIXME! slow
    -- @return: (number, offset).
    offset = offset + 1
    local n = double()
    local rstr = s_reverse(s_sub(str, offset, offset + 7))
    ffi.copy(n, rstr, 8)
    return n[0], offset + 8
end

function _M.double2(str, offset)
    offset = offset + 1
    local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(str, offset, offset + 7)
    local sign = b1 > 0x7F
    local expo = (b1 % 0x80) * 0x10 + floor(b2 / 0x10)
    local mant = ((((((b2 % 0x10) * 0x100 + b3) * 0x100 + b4) * 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8
    if sign then
        sign = -1
    else
        sign = 1
    end
    local n
    if mant == 0 and expo == 0 then
        n = sign * 0.0
    elseif expo == 0x7FF then
        if mant == 0 then
            n = sign * huge
        else
            n = 0.0/0.0
        end
    else
        n = sign * ldexp(1.0 + mant / 0x10000000000000, expo - 0x3FF)
    end
    return n, offset + 8
end

function _M.fixstr(str, offset)
    local len = string.byte(str, offset) - spec.fixstr1
    offset = offset + 1
    return s_sub(str, offset, len + offset - 1), len + offset
end

function _M.string8(str, offset)
    offset = offset + 1
    len = string.byte(str, offset)
    return s_sub(str, offset + 1, len + offset), len + offset + 1
end

function _M.string16(str, offset)
    offset = offset + 1
    local len_2byte = s_reverse(s_sub(str, offset, offset + 1))
    local len = uint16()
    ffi.copy(len, len_2byte, 2)
    len = len[0]
    return s_sub(str, offset + 2, len + offset + 1), len + offset + 2
end

function _M.string32(str, offset)
    offest = offset + 1
    local len_4byte = s_reverse(s_sub(str, offset, offset + 3))
    local len = uint32()
    ffi.copy(len, len_4byte, 4)
    len = len[0]
    return s_sub(str, offset + 4, len + offset + 3), len + offset + 4
end

function _M.fixarray(str, offset)
    local nitem = string.byte(str, offset) - spec.fixarray1
    local objs = {}
    local head
    offset = offset + 1
    for i=1,nitem do
        head = string.byte(str, offset)
        objs[i], offset = _M.unpackers[head](str, offset)
    end
    return objs, offset
end

function _M.array16(str, offset)
    local len_2byte = s_reverse(s_sub(str, offset + 1, offset + 2))
    local nitem = uint16()
    ffi.copy(nitem, len_2byte, 2)
    nitem = nitem[0]
    local objs = {}
    local head
    offset = offset + 3
    for i=1,nitem do
        head = string.byte(str, offset)
        objs[i], offset = _M.unpackers[head](str, offset)
    end
    return objs, offset
end

function _M.array32(str, offset)
    local len_4byte = s_reverse(s_sub(str, offset + 1, offset + 4))
    local nitem = uint32()
    ffi.copy(nitem, len_4byte, 4)
    nitem = nitem[0]
    local objs = {}
    local head
    offset = offset + 5
    for i=1,nitem do
        head = string.byte(str, offset)
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
    local head = string.byte(str, offset)
    return _M.unpackers[head](str, offset)
end

return _M
