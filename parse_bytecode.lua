local lcc = { -- from luac.c
    POS_OP = 0,
    SIZE_OP = 7,
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