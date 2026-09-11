local panel_active, combo_was_down = false, false
local screen, manager_selected, detail_selected = "manager", 1, 1
local manager_message = ""
local MODS_PER_PAGE = 4

local mod_list = {}

local function short_error(err)
    local text = tostring(err); return string.sub(string.match(text, "([^:]+)$") or text, 1, 44)
end

local mod_directories = mods.list()
table.sort(mod_directories)
for _, directory in ipairs(mod_directories) do
    local path = "ms0:/mods/" .. directory .. "/mod.lua"
    local ok, result = pcall(function() return mods.load_lua(path)() end)
    if ok and type(result) == "table" then
        result.settings = result.settings or {}
        table.insert(mod_list, result)
    else
        manager_message = short_error(ok and "mod.lua did not return a mod table" or result)
    end
end

local game_id = system.game_id() or "UNKNOWN"
local saved_mods = {}
local ok_state, state_data = pcall(mods.load_state, game_id)
if ok_state then
    for id in string.gmatch(state_data, "[^\r\n]+") do saved_mods[id] = true end
else
    manager_message = short_error(state_data)
end

for _, mod in ipairs(mod_list) do
    if saved_mods[tostring(mod.id)] and not mod.is_enabled() then
        local ok, err = pcall(mod.enable)
        if not ok then manager_message = short_error(err) end
    end
end

local function save_state()
    local active = {}
    for _, mod in ipairs(mod_list) do
        if mod.is_enabled() then active[#active + 1] = tostring(mod.id) end
    end
    table.sort(active)
    local ok, err = pcall(mods.save_state, game_id, table.concat(active, "\n"))
    if not ok then manager_message = short_error(err) end
end

local function toggle_mod(mod)
    manager_message = ""
    local ok, err
    if mod.is_enabled() then ok, err = pcall(mod.disable) else ok, err = pcall(mod.enable) end
    if ok then save_state() else manager_message = short_error(err) end
end

local function clamp(v, a, b)
    if v < a then return a elseif v > b then return b end
    return v
end

local function option(text, y, focused)
    if focused then
        overlay.text("> " .. text, 88, y, 1, 255, 220, 90, 255)
    else
        overlay.text("  " .. text, 88, y, 1, 240, 240, 240, 255)
    end
end

local function frame(title)
    overlay.rect(70, 48, 340, 176, 5, 8, 14, 225); overlay.rect(70, 48, 340, 3, 245, 180, 45, 255); overlay.rect(70, 221,
        340, 3, 245, 180, 45, 255)
    overlay.text(title, 88, 65, 1, 255, 220, 90, 255)
end

local function manager()
    local page_count = math.max(1, math.ceil(#mod_list / MODS_PER_PAGE))
    if #mod_list > 0 then
        if input.pressed("UP") then manager_selected = clamp(manager_selected - 1, 1, #mod_list) end
        if input.pressed("DOWN") then manager_selected = clamp(manager_selected + 1, 1, #mod_list) end
        if input.pressed("LEFT") then manager_selected = clamp(manager_selected - MODS_PER_PAGE, 1, #mod_list) end
        if input.pressed("RIGHT") then manager_selected = clamp(manager_selected + MODS_PER_PAGE, 1, #mod_list) end
    end
    local page = math.floor((manager_selected - 1) / MODS_PER_PAGE) + 1
    frame("MOD MANAGER")
    overlay.text(string.format("PAGE %d/%d", page, page_count), 320, 65, 1, 155, 170, 195, 255)
    if #mod_list == 0 then
        overlay.text("NO MODS LOADED", 88, 102, 1, 255, 100, 100, 255)
    else
        local first = (page - 1) * MODS_PER_PAGE + 1
        local last = math.min(first + MODS_PER_PAGE - 1, #mod_list)
        for i = first, last do
            local mod = mod_list[i]
            local y = 92 + (i - first) * 22; option(mod.name, y, i == manager_selected)
            overlay.text(mod.is_enabled() and "[X]" or "[ ]", 366, y, 1, mod.is_enabled() and 100 or 210,
                mod.is_enabled() and 255 or 130, 120, 255)
        end
        local current = mod_list[manager_selected]
        overlay.text(current.game or "", 88, 172, 1, 155, 170, 195, 255)
        if input.pressed("X") then toggle_mod(current) end
        if input.pressed("TRIANGLE") then
            screen = "detail"; detail_selected = 1
        end
    end

    overlay.text("X: TOGGLE  TRIANGLE: DETAILS", 88, 184, 1, 170, 180, 195, 255); overlay.text("LEFT/RIGHT: PAGE", 292, 184, 1, 170, 180,
        195, 255)
    if manager_message ~= "" then overlay.text(manager_message, 88, 204, 1, 255, 120, 90, 255) end
end

local function detail()
    local mod = mod_list[manager_selected]
    mod.settings = mod.settings or {}
    local count = #mod.settings + 2
    frame(mod.name .. " MOD")
    if input.pressed("UP") then detail_selected = clamp(detail_selected - 1, 1, count) end
    if input.pressed("DOWN") then detail_selected = clamp(detail_selected + 1, 1, count) end
    if detail_selected == 1 and input.pressed("X") then
        toggle_mod(mod)
    end

    for i, setting in ipairs(mod.settings) do
        local row = i + 1
        if detail_selected == row then
            local change = 0; if input.pressed("RIGHT") then change = 1 end; if input.pressed("LEFT") then change = -1 end
            if change ~= 0 then setting.set(clamp(setting.get() + change, setting.min, setting.max)) end
        end
    end

    if detail_selected == count and input.pressed("X") then screen = "manager" end
    option("ENABLED", 94, detail_selected == 1)
    overlay.text(mod.is_enabled() and "[X]" or "[ ]", 366, 94, 1, mod.is_enabled() and 100 or 210,
        mod.is_enabled() and 255 or 130, 120, 255)
    for i, setting in ipairs(mod.settings) do option(string.format("%s: %d", setting.name, setting.get()), 94 + i * 27,
            detail_selected == i + 1) end
    option("BACK", 94 + (count - 1) * 27, detail_selected == count)
    overlay.text("UP/DOWN: SELECT LEFT/RIGHT: VALUE", 88, 184, 1, 150, 165, 185, 255)
    local status = manager_message ~= "" and manager_message or (mod.status and mod.status() or "")
    if status ~= "" then overlay.text(status, 88, 204, 1, 255, 150, 90, 255) end
end

function draw()
    local combo = input.down("L") and input.down("R") and input.down("SELECT")
    if combo and not combo_was_down then panel_active = not panel_active end; combo_was_down = combo
    for _, mod in ipairs(mod_list) do if mod.update then mod.update() end end
    for _, mod in ipairs(mod_list) do if mod.is_enabled() and mod.draw then mod.draw() end end
    if not panel_active then return end
    if screen == "manager" then manager() else detail() end
end
