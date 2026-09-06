local root = "ms0:/mods/damage_numbers/"
local game_id = system.game_id()
local hook_file = game_id == "ULUS10391" and "hooks/mhfu_us.lua" or game_id == "ULJM05500" and "hooks/mhp2ndg_jp.lua" or
nil
local variant = hook_file and mods.load_lua(root .. hook_file)() or nil
local enabled = mods.is_active("damage_numbers")
local font_size = 12
local message = ""

local mod = { id = "damage_numbers", name = "DAMAGE NUMBER DISPLAY v0.4 by Lunng", game = variant and variant.label or
"UNSUPPORTED GAME" }

function mod.is_enabled() return enabled end

function mod.status() return message end

function mod.enable()
    if not variant then error("unsupported game") end
    for _, item in ipairs(variant.bins) do mods.load_bin(root .. "bins/" .. item[1], item[2]) end
    memory.write8(variant.config, 1); memory.write8(variant.config + 1, font_size)
    for _, hook in ipairs(variant.hooks) do mods.hook32("damage_numbers", hook[1], hook[2]) end
    enabled = true; message = "MOD ENABLED"
end

function mod.disable()
    if variant then memory.write8(variant.config, 0) end
    mods.disable("damage_numbers"); enabled = false; message = "MOD DISABLED"
end

function mod.update()
    if enabled and variant then
        memory.write8(variant.config, 1); memory.write8(variant.config + 1, font_size)
    end
end

mod.settings = { { name = "FONT SIZE", min = 10, max = 100, get = function() return font_size end, set = function(v) font_size =
    v end } }
return mod
