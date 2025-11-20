local function getOpcode(i)
    return (((((i)>>0) & ((~((~0)<<(7)))<<(0)))))
end

---parse instruction
---@param instr integer
local function parseInstruction(instr)
    local opcode = getOpcode(instr)
    print("opcode", opcode)
end

parseInstruction(81)