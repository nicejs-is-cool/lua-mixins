local function enum(stuff)
    local retv = {}
    for k, v in ipairs(stuff)
    do
        retv[v] = k
        retv[k] = v
    end
    return retv
end
local lcc = { -- from luac.c
    POS_OP = 0,
    SIZE_OP = 7,
    OpCode = enum { "OP_MOVE", "OP_LOADI", "OP_LOADF", "OP_LOADK", "OP_LOADKX", "OP_LOADFALSE", "OP_LFALSESKIP", "OP_LOADTRUE", "OP_LOADNIL", "OP_GETUPVAL", "OP_SETUPVAL", "OP_GETTABUP", "OP_GETTABLE", "OP_GETI", "OP_GETFIELD", "OP_SETTABUP", "OP_SETTABLE", "OP_SETI", "OP_SETFIELD", "OP_NEWTABLE", "OP_SELF", "OP_ADDI", "OP_ADDK", "OP_SUBK", "OP_MULK", "OP_MODK", "OP_POWK", "OP_DIVK", 
"OP_IDIVK", "OP_BANDK", "OP_BORK", "OP_BXORK", "OP_SHRI", "OP_SHLI", "OP_ADD", "OP_SUB", "OP_MUL", "OP_MOD", "OP_POW", "OP_DIV", "OP_IDIV", "OP_BAND", "OP_BOR", "OP_BXOR", "OP_SHL", "OP_SHR", "OP_MMBIN", "OP_MMBINI", "OP_MMBINK", "OP_UNM", "OP_BNOT", "OP_NOT", "OP_LEN", "OP_CONCAT", "OP_CLOSE", "OP_TBC", "OP_JMP", "OP_EQ", "OP_LT", "OP_LE", "OP_EQK", "OP_EQI", "OP_LTI", "OP_LEI", "OP_GTI", "OP_GEI", "OP_TEST", "OP_TESTSET", "OP_CALL", "OP_TAILCALL", "OP_RETURN", "OP_RETURN0", "OP_RETURN1", "OP_FORLOOP", "OP_FORPREP", "OP_TFORPREP", "OP_TFORCALL", "OP_TFORLOOP", "OP_SETLIST", "OP_CLOSURE", "OP_VARARG", "OP_VARARGPREP", "OP_EXTRAARG" }
}
function lcc.MASK1(n, p)
    return ((~((~0)<<(n)))<<(p))
end
function lcc.MASK0(n, p)
    return (~lcc.MASK1(n,p))
end

function lcc.GET_OPCODE(i)
    return ((i)>>lcc.POS_OP) & lcc.MASK1(lcc.SIZE_OP,0)
end

---parse instruction
---@param instr integer
local function parseInstruction(instr)
    local opcode = lcc.GET_OPCODE(instr)
    print("opcode", opcode)
end

parseInstruction(81)