local id = "hitbox_injector"
local root = "ms0:/mods/hitbox_injector/"
local game_id = system.game_id()
local config_path = root .. "definitions/" .. game_id .. ".lua"
local ok, definitions = pcall(function() return mods.load_lua(config_path)() end)
if not ok then definitions = {} end

local enabled = mods.is_active(id)
local originals = {}
local applied = 0
local message = ok and "READY" or "NO DEFINITIONS FOR THIS GAME"

local mod = {
    id = id,
    name = "HITBOX INJECTOR",
    game = game_id or "UNKNOWN",
    settings = {}
}

local function float_bits(value)
    return string.unpack("<I4", string.pack("<f", value))
end

local function valid_address(address)
    return type(address) == "number" and address >= 0x08800000 and address <= 0x09FFFFD8
end

local function valid_definition(shape)
    if type(shape) ~= "table" or not valid_address(shape.address) then return false end
    if shape.kind ~= "sphere" and shape.kind ~= "capsule" then return false end
    if type(shape.radius) ~= "number" or shape.radius <= 0 then return false end
    if type(shape.a) ~= "table" or #shape.a < 3 then return false end
    return shape.kind ~= "capsule" or (type(shape.b) == "table" and #shape.b >= 3)
end

local function save_original(index, address)
    local words = {}
    for offset = 0, 0x24, 4 do words[#words + 1] = memory.read32(address + offset) end
    originals[index] = words
    return words
end

local function write_float(address, value)
    memory.write32(address, float_bits(value))
end

local function apply_shape(index, shape)
    if not valid_definition(shape) then return false end
    local address = shape.address
    local words = originals[index]
    if not words then
        local header = memory.read32(address)
        local bone = header % 0x10000
        local current_type = math.floor(header / 0x10000) % 0x10000
        local current_radius = memory.read_float(address + 0x0C)
        if bone > 0x7F or current_type > 1 or current_radius ~= current_radius
            or current_radius <= 0 or current_radius > 100000 then return false end
        words = save_original(index, address)
    end
    local original_header = words[1]
    local desired_type = shape.kind == "capsule" and 0 or 1
    local desired_header = (original_header % 0x10000) + desired_type * 0x10000
    local current_header = memory.read32(address)

    -- Stop touching the address if another overlay replaced this descriptor.
    if current_header ~= original_header and current_header ~= desired_header then
        originals[index] = nil
        return false
    end

    memory.write16(address + 2, desired_type)
    write_float(address + 0x0C, shape.radius)
    write_float(address + 0x10, shape.a[1])
    write_float(address + 0x14, shape.a[2])
    write_float(address + 0x18, shape.a[3])
    if shape.kind == "capsule" then
        write_float(address + 0x1C, shape.b[1])
        write_float(address + 0x20, shape.b[2])
        write_float(address + 0x24, shape.b[3])
    end
    return true
end

function mod.is_enabled() return enabled end
function mod.status() return message end

function mod.enable()
    if #definitions == 0 then error("no hitbox definitions for " .. tostring(game_id)) end
    enabled = true
    message = "WAITING FOR HITBOX DATA"
end

function mod.disable()
    for index, words in pairs(originals) do
        local shape = definitions[index]
        if shape and valid_address(shape.address) then
            for word = 1, #words do memory.write32(shape.address + (word - 1) * 4, words[word]) end
        end
    end
    originals = {}
    applied = 0
    enabled = false
    message = "INJECTOR DISABLED"
end

function mod.update()
    if not enabled then return end
    local count = 0
    for index, shape in ipairs(definitions) do
        if apply_shape(index, shape) then count = count + 1 end
    end
    applied = count
    message = string.format("APPLIED %d/%d", applied, #definitions)
end

return mod
