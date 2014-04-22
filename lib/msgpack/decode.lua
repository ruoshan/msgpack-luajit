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

function _M.decode_double(str, offset)
    -- @return: (number, offset).
    offset = offset + 1
    local n = double()
    local rstr = s_reverse(s_sub(str, offset, offset + 7))
    ffi.copy(n, rstr, 8)
    return n[0], offset + 8
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
        return s_sub(str, offset, len + offset - 1), len + offset
    elseif head1 == spec.str8 then
        len = string.byte(str, offset)
        return s_sub(str, offset + 1, len + offset), len + offset + 1
    elseif head1 == spec.str16 then
        head2 = s_reverse(s_sub(str, offset, offset + 1))
        len = uint16()
        ffi.copy(len, head2, 2)
        len = len[0]
        return s_sub(str, offset + 2, len + offset + 1), len + offset + 2
    elseif head1 == spec.str32 then
        head2 = s_reverse(s_sub(str, offset, offset + 3))
        len = uint32()
        ffi.copy(len, head2, 4)
        len = len[0]
        return s_sub(str, offset + 4, len + offset + 3), len + offset + 4
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
        head2 = s_reverse(s_sub(str, offset, offset + 1))
        len = uint16()
        ffi.copy(len, head2, 2)
        len = len[0]
        return len, offset + 2
    elseif head1 == spec.array32 then
        head2 = s_reverse(s_sub(str, offset, offset + 3))
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
