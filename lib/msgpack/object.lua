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

---------------------------
-- Serialization related --
---------------------------

function _M.double(number)
    local head1 = string.char(spec.float64)
    local obj_str = string.reverse(ffi.string(double(number), 8))
    return head1 .. obj_str
end

local function _family0135(obj_str, len, headers, ranges)
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
        local head2 = string.reverse(ffi.string(byte2(len)))
        return head1 .. head2 .. obj_str
    elseif len < ranges[4] then
        local head1 = string.char(headers[4])
        local head2 = string.reverse(ffi.string(byte4(len)))
        return head1 .. head2 .. obj_str
    end
    return nil
end

function _M.string(str)
    local len = string.len(str)
    local headers = {spec.fixstr1, spec.str8, spec.str16, spec.str32}
    local ranges = {31, 0xFF, 0xFFFF, 0xFFFFFFFF}
    return _family0135(str, len, headers, ranges)
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
    return _family0135(table.concat(childs), len, headers, ranges)
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
    local rstr = string.reverse(str)
    local data = string.sub(rstr, 1, 8)
    local number = double()
    ffi.copy(number, data, 8)
    return number[0], 9
end

function _M._dfamily0135(str, headers)
    local head1 = string.byte(str)
    local head2
    local len
    if head1 >= headers[1] and head1 <= headers[2] then
        -- fixstr
        len = head1 - spec.fixstr1
        return string.sub(str, 2, len + 1), len
    elseif head1 == headers[3] then
        len = string.byte(str, 2, 2)
        return string.sub(str, 3, len + 2), len
    elseif head1 == headers[4] then
        head2 = string.reverse(string.sub(str, 2, 3))
        len = byte2()
        ffi.copy(len, head2, 2)
        len = len[0]
        return string.sub(str, 4, len + 3), len
    elseif head1 == headers[5] then
        head2 = string.reverse(string.sub(str, 2, 5))
        len = byte4()
        ffi.copy(len, head2, 4)
        len = len[0]
        return string.sub(str, 4, len + 5), len
    end
    return nil, 0
end

function _M.dstring(str)
    local headers = {spec.fixstr1, spec.fixstr2, spec.str8, spec.str16, spec.str32}
    return _M._dfamily0135(str, headers)
end

function _M.darray(str)
    local headers = {spec.fixarray1, spec.fixarray2, nil, spec.array16, spec.array32}
end

return _M
