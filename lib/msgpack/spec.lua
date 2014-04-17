--------------------------------------------------------
-- This is a Luajit module for MsgPack v5 spec.       --
-- [NOTE] ONLY work on Luajit                         --
--                                                    --
--                                                    --
-- Copyright: Ruoshan Huang                           --
-- Email:  ruoshan.huang[AT]gmail.com                 --
--------------------------------------------------------

-- MsgPack v5 SPEC header byte

local _M = {}

_M.pfixint  = 0x00
_M.fixmap   = 0x80
_M.fixarray = 0x90
_M.fixstr   = 0xA0
_M["nil"]   = 0xC0
_M["false"] = 0xC2
_M["true"]  = 0xC3
_M.bin8     = 0xC4
_M.bin16    = 0xC5
_M.bin32    = 0xC6
_M.ext8     = 0xC7
_M.ext16    = 0xC8
_M.ext32    = 0xC9
_M.float32  = 0xCA
_M.float64  = 0xCB
_M.uint8    = 0xCC
_M.uint16   = 0xCD
_M.uint32   = 0xCE
_M.uint64   = 0xCF
_M.int8     = 0xD0
_M.int16    = 0xD1
_M.int32    = 0xD2
_M.int64    = 0xD3
_M.fixext1  = 0xD4
_M.fixext2  = 0xD5
_M.fixext4  = 0xD6
_M.fixext8  = 0xD7
_M.fixext16 = 0xD8
_M.str8     = 0xD9
_M.str16    = 0xDA
_M.str32    = 0xDB
_M.array16  = 0xDC
_M.array32  = 0xDD
_M.map16    = 0xDE
_M.map32    = 0xDF
_M.nfixint  = 0xE0

return _M
