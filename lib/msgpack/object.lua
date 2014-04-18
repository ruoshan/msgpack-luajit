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
local uint16 = ffi.typeof("uint16_t [1]")
local uint32 = ffi.typeof("uint32_t [1]")

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
        print("=", len)
        local head2 = string.reverse(ffi.string(uint16(len), 2))
        return head1 .. head2 .. items
    elseif len < 0xFFFFFFFF then
        local head1 = string.char(spec.array32)
        local head2 = string.reverse(ffi.string(uint32(len), 4))
        return head1 .. head2 .. items
    end
end

function _M.encode_array(arr)
    local len = #arr
    local childs = {}
    local t
    for i,v in ipairs(arr) do
        t = type(v)
        if t == "number" then
            childs[#childs + 1] = _M.encode_double(v)
        elseif t == "string" then
            childs[#childs + 1] = _M.encode_string(v)
        elseif t == "table" then
            childs[#childs + 1] = _M.encode_array(v)
        end
    end
    return _M._encode_array(table.concat(childs), len, headers, ranges)
end

-----------------------------
-- Deserialization related --
-----------------------------

function _M.is_array(head)
    if ((head >= spec.fixarray1 and
             head <= spec.fixarray2) or
            head == spec.array16 or
            head == spec.array32)
    then
        return true
    end
    return false
end

function _M.is_string(head)
    if ((head >= spec.fixstr1 and
             head <= spec.fixstr2) or
            head == spec.str8 or
            head == spec.str16 or
            head == spec.str32)
    then
        return true
    end
    return false
end

function _M.is_double(head)
    if (head == spec.float64) then
        return true
    end
    return false
end

function _M.decode_double(str)
    -- @return: (number, len). len: the length of string consumed
    local head1 = string.byte(str)
    if head1 ~= spec.float64 then
        return nil, 0
    end
    local rstr = string.reverse(string.sub(str, 1, 9))
    local data = string.sub(rstr, 1, 8)
    local number = double()
    ffi.copy(number, data, 8)
    return number[0], 9
end

function _M.decode_string(str)
    -- @return: (data, len). len the length of string consumed
    local head1 = string.byte(str)
    local head2
    local len
    if head1 >= spec.fixstr1 and head1 <= spec.fixstr2 then
        -- fixstr
        len = head1 - spec.fixstr1
        return string.sub(str, 2, len + 1), len + 1
    elseif head1 == spec.str8 then
        len = string.byte(str, 2, 2)
        return string.sub(str, 3, len + 2), len + 2
    elseif head1 == spec.str16 then
        head2 = string.reverse(string.sub(str, 2, 3))
        len = uint16()
        ffi.copy(len, head2, 2)
        len = len[0]
        return string.sub(str, 4, len + 3), len + 3
    elseif head1 == spec.str32 then
        head2 = string.reverse(string.sub(str, 2, 5))
        len = uint32()
        ffi.copy(len, head2, 4)
        len = len[0]
        return string.sub(str, 6, len + 5), len + 5
    end
    return nil, 0
end

function _M._decode_array(str)
    -- @return: (data, len). len: number of items in array
    local head1 = string.byte(str)
    local head2
    local len
    if head1 >= spec.fixarray1 and head1 <= spec.fixarray2 then
        -- fixstr
        len = head1 - spec.fixarray1
        return string.sub(str, 2), len
    elseif head1 == spec.array16 then
        head2 = string.reverse(string.sub(str, 2, 3))
        len = uint16()
        ffi.copy(len, head2, 2)
        len = len[0]
        return string.sub(str, 3), len
    elseif head1 == spec.array32 then
        head2 = string.reverse(string.sub(str, 2, 5))
        len = uint32()
        ffi.copy(len, head2, 4)
        len = len[0]
        return string.sub(str, 5), len
    end
    return nil, 0
end

function _M.decode_array(str)
    local substr, nitem = _M._decode_array(str)
    local objs = {}
    local len = 0
    local head, sublen
    for i=1,nitem do
        head = string.byte(substr)
        if _M.is_double(head) then
            objs[#objs + 1], sublen = _M.decode_double(substr)
            substr = string.sub(substr, sublen + 1)
        elseif _M.is_string(head) then
            objs[#objs + 1], sublen = _M.decode_string(substr)
            substr = string.sub(substr, sublen + 1)
        elseif _M.is_array(head) then
            objs[#objs + 1], sublen = _M.decode_array(substr)
            substr = string.sub(substr, sublen + 1)
        end
        len = len + sublen
    end
    return objs, len
end

return _M
