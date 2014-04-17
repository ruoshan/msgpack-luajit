# About

This is a partial [MessagePack](http://msgpack.org) implementation for
serilize the lua Number, String and Array(table) into binary string.
Please _NOTE_ that this module __ONLY__ run on [luajit](http://luajit.org).

Performance is the main goal here. I try not to include any NYI
[Bytecode](http://wiki.luajit.org/NYI).
This explains why hash table is _NOT_ implemented, as iterating through
hash table requires `pairs`, which generates a NYI Bytecode.

Other option may be [lua-MessagePack](http://fperrad.github.io/lua-MessagePack/).
`luajit-msgpack` is much faster than `lua-MessagePack` with more code be JIT compiled.

# Status

* msgpack.unpack() is NOT implemented yet.

# Usage

example,

    #!/usr/bin/env luajit
    package.path = "DIR/lib/?.lua;;"
    local mp = require "msgpack"

    local nested = {23.58, "hello world", {42, "the end"}}
    local serilized = mp.pack(nested)
    local deserilized = mp.unpack(serilized)

# License

This module is licensed under [MIT license](http://www.opensource.org/licenses/mit-license.php)

Copyright (C) Ruoshan Huang
