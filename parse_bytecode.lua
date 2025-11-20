local io = require("io")
local compiled, err = io.open("luac.out", "rb");
---Make lua type variant
---@param t integer
---@param v integer
---@return integer
local function makevariant(t, v)
    return ((t) | ((v) << 4))
end

local consts <const> = {
    LUAC_SIGNATURE = "\x1bLua",
    LUAC_DATA = "\x19\x93\r\n\x1a\n",
    LUAC_VERSION = (((504 // 100) * 16) + 504 % 100),
    LUAC_FORMAT = 0,
    LUAC_INT = 0x5678,
    LUAC_NUM = 370.5,
    sp_prefix = "=",
    sizes = {
        Instruction = string.packsize("I4"),
        lua_Integer = string.packsize("i8"),
        lua_Number = string.packsize("n")
    },
    INT_MAX = 2147483647,
    LUA_TNIL = 0,
    LUA_TBOOLEAN = 1,
    LUA_TNUMBER = 3,
    LUA_TSTRING = 4
}
consts.LUA_VNIL = makevariant(consts.LUA_TNIL, 0)
consts.LUA_VFALSE = makevariant(consts.LUA_TBOOLEAN, 0)
consts.LUA_VTRUE = makevariant(consts.LUA_TBOOLEAN, 1)
consts.LUA_VNUMINT = makevariant(consts.LUA_TNUMBER, 0)
consts.LUA_VNUMFLT = makevariant(consts.LUA_TNUMBER, 1)
consts.LUA_VSHRSTR = makevariant(consts.LUA_TSTRING, 0) -- short strings
consts.LUA_VLNGSTR = makevariant(consts.LUA_TSTRING, 1) -- long strings

if compiled == nil then
    print("error:", err)
    return
end
---@class Proto
---@field numparams integer
---@field is_vararg integer
---@field maxstacksize integer
---@field k any
---@field code any[]
---@field p Proto[]
---@field upvalues table[]
---@field sizeupvalues integer
---@field lineinfo number[]
---@field abslineinfo any[]
---@field locvars any[]
---@field source string
---
---@class TValue
---@field _tt string
---@field value_ any
---Typed value
---@param _tt string
---@param value_ any
---@return TValue
local function TValue_new(_tt, value_)
    return {
        _tt = _tt,
        value_ = value_
    }
end

---Creates a load* function wrapper.
---@param sfmt string
---@return fun(h: file*): number
local function _loadWrapper(sfmt)
    return function (h)
        local psize = string.packsize(consts.sp_prefix .. sfmt)
        return string.unpack(consts.sp_prefix .. sfmt, h:read(psize))
    end
end
local loadByte = _loadWrapper("B")
local loadInteger = _loadWrapper("i8")
local loadNumber = _loadWrapper("n")
---Load unsigned value i guess??? (i don't know what the lua devs were smoking when they wrote this)
---@param h file*
---@return number
local function loadUnsigned(h)
    local x = 0
    local b = 0
    --limit = limit >> 7
    while (b & 0x80) == 0 do
        print("iter")
        b = loadByte(h)
        --[[if x >= limit then
            return false, "integer overflow"
        end]]
        x = (x << 7) | (b & 0x7f)
    end
    return x
end

local function loadSize(h)
    return loadUnsigned(h)
end

local function loadInt(h)
    return loadUnsigned(h)
end
---load vector
---@param h file*
---@param fmt string
---@param n integer
---@return table
local function loadVector(h, fmt, n)
    --local size = string.packsize(fmt) * n
    local size = n
    print("sizeeeee", size)
    local vals = {}
    for i = 1, n-1, 1
    do
        local str, err = h:read(size)
        print(string.format("str recv: %q, %s", str, err))
        local d = string.unpack(fmt, str)
        table.insert(vals, d)
    end
    return vals
end
---Load string.
---@param h file*
---@return string?
local function loadStringN(h)
    print(h:seek("cur"))
    local size = loadSize(h) - 1
    --print(suc, size)
    if size == 0 then
        return nil
    end
    return h:read(size)
end
---Load non-nullable string
---@param h file*
---@return boolean, string
local function loadString(h)
    local st = loadStringN(h)
    if st == nil then
        return false, "bad format for constant string"
    end
    return true, st
end

---Load function code
---@param h file*
---@return table
local function loadCodeRaw(h)
    local n = loadInt(h)
    local bytes = n * consts.sizes.Instruction
    print("bytes = ", bytes)
    return {
        code = h:read(bytes),
        count = n
    }
end
---Load function constants
---@param h file*
---@return TValue[]
local function loadConstants(h)
    --local i = 0;
    local n = loadInt(h)

    print("fucking n", n)
    local typehandler = {
        [consts.LUA_VNIL] = function ()
            --print("vnil")
            return TValue_new("nil")
        end,
        [consts.LUA_VFALSE] = function ()
            --print("vfalse")
            return TValue_new("boolean", false)
        end,
        [consts.LUA_VTRUE] = function ()
            --print("vtrue")
            return TValue_new("boolean", true)
        end,
        [consts.LUA_VNUMFLT] = function ()
            --print("vnumflt")
            return TValue_new("float", loadNumber(h))
        end,
        [consts.LUA_VNUMINT] = function ()
            --print("vnumint")
            return TValue_new("number", loadInteger(h))
        end,
        [consts.LUA_VSHRSTR] = function (self, t)
            --print("vshrstr")
            local success, str = loadString(h)
            if not success then
                return error(str) -- fuck it
            end
            return TValue_new("string", str)
        end,
        [consts.LUA_VLNGSTR] = function (self, ...)
            return self[consts.LUA_VSHRSTR](self, ...)
        end
    }
    local retv = {}
    for i = 1, n, 1
    do
        local t = loadByte(h)
        print("type=", t)
        local val = typehandler[t](typehandler, t)
        table.insert(retv, val)
        
    end
    return retv
end
local function loadUpvalues(h)
    local n = loadInt(h)
    local upvalues = {}
    for i = 1, n, 1
    do
        table.insert(upvalues, {
            name = nil,
            instack = loadByte(h),
            idx = loadByte(h),
            kind = loadByte(h)
        })
    end
    return upvalues
end
local function readAbsLineInfo(h, n)
    local ps = string.packsize("ii")
    local retv = {}
    for i = 1, n, 1
    do
        local pc, line = string.unpack("ii", h:read(ps))
        table.insert(retv, { pc = pc, line = line })
    end
    return retv
end
---load debug info
---@param h file*
---@param proto Proto
local function loadDebug(h, proto)
    local lin = loadInt(h)
    print("lin = ", lin)
    proto.lineinfo = loadVector(h, "b", lin)
    for k, v in ipairs(proto.lineinfo)
    do
        print("line", k, v)
    end
    local alin = loadInt(h)
    proto.abslineinfo = readAbsLineInfo(h, alin)
    local locVarN = loadInt(h)
    proto.locvars = {}
    for i = 1, locVarN, 1
    do
        table.insert(proto.locvars, {
            varname = loadStringN(h),
            startpc = loadInt(h),
            endpc = loadInt(h)
        })
    end
    local upvalueCount = loadInt(h)
    if upvalueCount ~= 0 then
        proto.sizeupvalues = upvalueCount
    end
    for i = 1, upvalueCount, 1
    do
        proto.upvalues[i].name = loadStringN(h)
    end
end

local function checksize(h, size, tname)
    if loadByte(h) ~= size then
        return false, tname .. " size mismatch"
    end
    return true
end

---Check the header of a lua compiled chunk.
---@param h file*
---@return boolean, string | table
local function checkHeader(h)
    if h == nil then
        return false, "nil file handle"
    end
    local luacSignature = h:read(4)
    if luacSignature ~= consts.LUAC_SIGNATURE then
        return false, "not a binary chunk"
    end
    local luacVersion = h:read(1)
    if luacVersion ~= string.char(consts.LUAC_VERSION) then
        return false, "version mismatch"
    end
    local luacFormat = h:read(1)
    if luacFormat ~= string.char(consts.LUAC_FORMAT) then
        return false, "format mismatch"
    end
    local luacData = h:read(#consts.LUAC_DATA)
    if luacData ~= consts.LUAC_DATA then
        return false, "corrupted chunk"
    end
    --h:read(#consts.LUAC_SIGNATURE-1) -- not sure what the hell is going on here but i need to skip 3 bytes for some reason
    do -- god i wish i had macros
        local success, err = checksize(h, consts.sizes.Instruction)
        if not success then return false, err or "" end
    end
    do
        local success, err = checksize(h, consts.sizes.lua_Integer)
        if not success then return false, err or "" end
    end
    do -- god i wish i had macros
        local success, err = checksize(h, consts.sizes.lua_Number)
        if not success then return false, err or "" end
    end

    if loadInteger(h) ~= consts.LUAC_INT then
        return false, "integer format mismatch"
    end
    if loadNumber(h) ~= consts.LUAC_NUM then
        return false, "float format mismatch"
    end

    return true, {
        signature = luacSignature,
        version = luacVersion,
        format = luacFormat,
        data = luacData,
    }
end
---@type fun(h: file*, psrc: string): table
local loadProtos
local function loadFunction(h, psource)
    print("load str")
    local src = loadStringN(h)
    if src == nil then
        src = psource
    end
    print('here')
    ---@type Proto
    local retv = {
        source = src,
        linedefined = loadInt(h),
        lastlinedefined = loadInt(h),
        numparams = loadByte(h),
        is_vararg = loadByte(h),
        maxstacksize = loadByte(h),
        code = loadCodeRaw(h),
        p = {},
        upvalues = {},
        sizeupvalues = 0,
        lineinfo = {},
        abslineinfo = {},
        locvars = {}
    }
    local cconsts = loadConstants(h)
    retv.k = cconsts
    for k, v in ipairs(cconsts)
    do
        print(string.format("const %s = {type=%s, value=%s}", k, v._tt, v.value_))
    end
    local upvalues = loadUpvalues(h)
    retv.upvalues = upvalues
    retv.sizeupvalues = #upvalues
    for k, v in ipairs(upvalues)
    do
        print(string.format("{instack=%q, idx=%q, kind=%q}", v.instack, v.idx, v.kind))
    end
    local protos = loadProtos(h, psource)
    retv.p = protos
    loadDebug(h, retv)
    return retv
end
loadProtos = function(h, psrc)
    local n = loadInt(h)
    local p = {}
    for i = 1, n, 1
    do
        table.insert(p, loadFunction(h, psrc))
    end
    return p
end
---Actually parse the chunk.
---@param h file*
local function parseChunk(h)
    local nupvals = loadByte(h) -- number of upvalues
    return loadFunction(h, "binary string")
end

print(checkHeader(compiled))
local chunk = parseChunk(compiled)
print(string.format([[source = %q
linedefined = %d
lastlinedefined = %d
numparams = %d
is_vararg = %d
maxstacksize = %d]], chunk.source, chunk.linedefined, chunk.lastlinedefined, chunk.numparams, chunk.is_vararg, chunk.maxstacksize))