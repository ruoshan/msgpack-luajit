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

function _M.double(number)
    local head1 = string.char(spec.float64)
    local obj_str = string.reverse(ffi.string(double(number), 8))
    return head1 .. obj_str
end

local function _family0124(obj_str, len, headers, ranges)
    -- 0: length is stored in the head byte
    -- 1: length is stored in the next byte
    -- 2: length is stored in the next two bytes
    -- 3: length is stored in the next four bytes
    if len <= ranges[1] then
        local head1 = string.char(headers[1] + len)
        return head1 .. obj_str
    elseif len < ranges[2] then
        local head1 = string.char(headers[2])
        local head2 = string.char(n)
        return head1 .. head2 .. obj_str
    elseif len < ranges[3] then
        local head1 = string.char(headers[3])
        local head2 = string.reverse(ffi.string(uint16(len)))
        return head1 .. head2 .. obj_str
    elseif len < ranges[4] then
        local head1 = string.char(headers[4])
        local head2 = string.reverse(ffi.string(uint32(len)))
        return head1 .. head2 .. obj_str
    end
    return nil
end

function _M.string(str)
    local len = string.len(str)
    local headers = {spec.fixstr1, spec.str8, spec.str16, spec.str32}
    local ranges = {31, 0xFF, 0xFFFF, 0xFFFFFFFF}
    return _family0124(str, len, headers, ranges)
end

function _M.array(arr)
    local len = #arr
    --NOTE: not spec for array8
    local headers = {spec.fixarray1, spec.array16, spec.array16, spec.array32}
    local ranges = {15, 0xFFFF, 0xFFFF, 0xFFFFFFFF}
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
    return _family0124(table.concat(childs), len, headers, ranges)
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

function _M.ddouble(str)
    -- @return: (number, len). len: the string consumed
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

function _M.dstring(str)
    -- @return: (data, len). len the string consumed
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

function _M._darray(str)
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

function _M.darray(str)
    local substr, nitem = _M._darray(str)
    local objs = {}
    local len = 0
    local head, sublen
    for i=1,nitem do
        head = string.byte(substr)
        if _M.is_double(head) then
            objs[#objs + 1], sublen = _M.ddouble(substr)
            substr = string.sub(substr, sublen + 1)
        elseif _M.is_string(head) then
            objs[#objs + 1], sublen = _M.dstring(substr)
            substr = string.sub(substr, sublen + 1)
        elseif _M.is_array(head) then
            objs[#objs + 1], sublen = _M.darray(substr)
            substr = string.sub(substr, sublen + 1)
        end
        len = len + sublen
    end
    return objs, len
end

return _M
