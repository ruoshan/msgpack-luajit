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


local double = ffi.typeof("double [1]")
local uint16 = ffi.typeof("uint16_t [1]")
local uint32 = ffi.typeof("uint32_t [1]")
local char8  = ffi.typeof("unsigned char [8]")
local uint32x2 = ffi.typeof("uint32_t [2]")

---------------------------
-- Serialization related --
---------------------------

function _M.encode_double(number)
    local head1 = string.char(spec.float64)
    local obj_str = string.reverse(ffi.string(double(number), 8))
    return head1 .. obj_str
end

function _M.encode_string(str)
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
        local head2 = string.reverse(ffi.string(uint16(len), 2))
        return head1 .. head2 .. str
    elseif len < 0xFFFFFFFF then
        local head1 = string.char(spec.str32)
        local head2 = string.reverse(ffi.string(uint32(len), 4))
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
        local head2 = string.reverse(ffi.string(uint16(len), 2))
        return head1 .. head2 .. items
    elseif len < 0xFFFFFFFF then
        local head1 = string.char(spec.array32)
        local head2 = string.reverse(ffi.string(uint32(len), 4))
        return head1 .. head2 .. items
    end
end

function _M.encode_array(arr)
    local childs = ""
    local t
    for i,v in ipairs(arr) do
        t = type(v)
        if t == "number" then
            childs = childs .. _M.encode_double(v)
        elseif t == "string" then
            childs = childs .. _M.encode_string(v)
        elseif t == "table" then
            childs = childs .. _M.encode_array(v)
        end
    end
    return _M._encode_array(childs, #arr, headers, ranges)
end

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

local function str2double(str8)
    -- convert big-endian double in string(8bit) array to little-endian double
    -- @str8: 8 bytes raw string
    local B32x2 = uint32x2()
    ffi.copy(B32x2, str8, 8)
    local i0, i1 = B32x2[0], B32x2[1]
    B32x2[1] = bit.bswap(i0)
    B32x2[0] = bit.bswap(i1)
    local d = double()
    ffi.copy(d, B32x2, 8)
    return d[0]
end

function _M.decode_double(str, offset)
    -- @return: (number, offset).
    offset = offset + 1
    local n = str2double(s_sub(str, offset, offset + 7))
    return n, offset + 8
end

function _M.decode_string(str, offset)
    -- @return: (data, offset).
    local head1 = string.byte(str, offset)
    offset = offset + 1
    local head2
    local len
    if head1 >= spec.fixstr1 and head1 <= spec.fixstr2 then
        -- fixstr
        len = head1 - spec.fixstr1
        return string.sub(str, offset, len + offset - 1), len + offset
    elseif head1 == spec.str8 then
        len = string.byte(str, offset)
        return string.sub(str, offset + 1, len + offset), len + offset + 1
    elseif head1 == spec.str16 then
        head2 = string.reverse(string.sub(str, offset, offset + 1))
        len = uint16()
        ffi.copy(len, head2, 2)
        len = len[0]
        return string.sub(str, offset + 2, len + offset + 1), len + offset + 2
    elseif head1 == spec.str32 then
        head2 = string.reverse(string.sub(str, offset, offset + 3))
        len = uint32()
        ffi.copy(len, head2, 4)
        len = len[0]
        return string.sub(str, offset + 4, len + offset + 3), len + offset + 4
    end
end

function _M._decode_array(str, offset)
    -- @offset: is the start position in the str. (includesive)
    -- @return: (n, offset).
    --          n: number of items in array
    --          offset: position of the real data. (includesive)
    local head1 = string.byte(str, offset)
    local head2
    local len
    offset = offset + 1
    if head1 >= spec.fixarray1 and head1 <= spec.fixarray2 then
        -- fixstr
        n = head1 - spec.fixarray1
        return n, offset
    elseif head1 == spec.array16 then
        head2 = string.reverse(string.sub(str, offset, offset + 1))
        len = uint16()
        ffi.copy(len, head2, 2)
        len = len[0]
        return len, offset + 2
    elseif head1 == spec.array32 then
        head2 = string.reverse(string.sub(str, offset, offset + 3))
        len = uint32()
        ffi.copy(len, head2, 4)
        len = len[0]
        return len, offset + 4
    end
end

function _M.decode_array(str, offset)
    local nitem, offset = _M._decode_array(str, offset)
    local objs = {}
    local head
    for i=1,nitem do
        head = string.byte(str, offset)
        if _M.is_double(head) then
            objs[i], offset = _M.decode_double(str, offset)
        elseif _M.is_string(head) then
            objs[i], offset = _M.decode_string(str, offset)
        elseif _M.is_array(head) then
            objs[i], offset = _M.decode_array(str, offset)
        end
    end
    return objs, offset
end

return _M
