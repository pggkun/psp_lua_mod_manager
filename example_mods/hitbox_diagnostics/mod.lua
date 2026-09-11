local id = "hitbox_diagnostics"
local root = "ms0:/mods/hitbox_diagnostics/"
local game_id = system.game_id()
local hook_file = game_id == "ULJM05500" and "hooks/mhp2ndg_jp.lua"
    or game_id == "ULUS10391" and "hooks/mhfu_us.lua" or nil
local variant = hook_file and mods.load_lua(root .. hook_file)() or nil
local enabled = mods.is_active(id)
local installed, skeleton_built = false, false
local last_generation, monster_address = 0, 0
local bones_found, bones_visible, bone_limit = 0, 0, 3
local hitbox_detail = 8
local hitbox_style = 0
local result_line = "DAMAGE PATH WAITING"
local builder_address = 0
local builder_scan_cursor = 0
local builder_saved = false
local builder_hooked = false
local builder_generation = 0
local hitbox_type, hitbox_radius = -1, 0
local hitbox_owner, hitbox_descriptor = 0, 0
local message = "HIT A MONSTER"
local status_line = "STATE WAITING FOR HIT"

local mod = { id = id, name = "HITBOX DIAGNOSTICS", game = variant and variant.label or "UNSUPPORTED GAME" }
function mod.is_enabled() return enabled end
function mod.status() return message end

local function valid_pointer(value)
    return value >= 0x08800000 and value < 0x0A000000
end

local function build_node_table()
    local count, address = 0, monster_address + 0x0800
    local limit = monster_address + 0x7C00
    while address < limit and count < 48 do
        if memory.read32(address) == variant.node_class then
            memory.write32(variant.node_table + 4 + count * 8, address)
            memory.write32(variant.node_table + 8 + count * 8, 0xFFFFFFFF)
            count = count + 1
        end
        address = address + 0x10
    end
    for i = 0, count - 1 do
        local node = memory.read32(variant.node_table + 4 + i * 8)
        local parent = memory.read32(node + variant.parent_offset)
        for j = 0, count - 1 do
            if memory.read32(variant.node_table + 4 + j * 8) == parent then
                memory.write32(variant.node_table + 8 + i * 8, j)
                break
            end
        end
    end
    memory.write32(variant.node_table, count)
    bones_found, skeleton_built = count, count > 0
    status_line = string.format("READY BONES %d LIMIT %d", count, bone_limit)
end

local function project_world(x, y, z)
    if x ~= x or y ~= y or z ~= z or math.abs(x) > 1000000 or math.abs(y) > 1000000 or math.abs(z) > 1000000 then
        return 0, 0, false
    end
    local m = variant.matrix
    local vx = memory.read_float(m) * x + memory.read_float(m + 16) * y
        + memory.read_float(m + 32) * z + memory.read_float(m + 48)
    local vy = memory.read_float(m + 4) * x + memory.read_float(m + 20) * y
        + memory.read_float(m + 36) * z + memory.read_float(m + 52)
    local vz = memory.read_float(m + 8) * x + memory.read_float(m + 24) * y
        + memory.read_float(m + 40) * z + memory.read_float(m + 56)
    local depth = -vz
    if vx ~= vx or vy ~= vy or vz ~= vz or depth < 0.01 or depth > 1000000 then return 0, 0, false end
    local sx = math.floor((1.21502685546875 * vx / depth + 1) * 240)
    local sy = math.floor((1 - 2.14447021484375 * vy / depth) * 136)
    return sx, sy, sx >= 0 and sx < 480 and sy >= 0 and sy < 272
end

local function project(node)
    if not valid_pointer(node) or memory.read32(node) ~= variant.node_class then return 0, 0, false end
    local p = variant.position_offset
    return project_world(memory.read_float(node + p), memory.read_float(node + p + 4),
        memory.read_float(node + p + 8))
end

local function draw_safe_line(x0, y0, x1, y1)
    local dx, dy = x1 - x0, y1 - y0
    local distance = math.max(math.abs(dx), math.abs(dy))
    if distance < 1 then return end
    local samples = math.min(24, distance)
    for sample = 0, samples do
        overlay.rect(math.floor(x0 + dx * sample / samples),
            math.floor(y0 + dy * sample / samples), 1, 1, 64, 255, 64, 255)
    end
end

local function draw_world_ring(cx, cy, cz, ux, uy, uz, vx, vy, vz)
    local first_x, first_y, first_visible = 0, 0, false
    local previous_x, previous_y, previous_visible = 0, 0, false
    for i = 0, hitbox_detail - 1 do
        local angle = i * 6.283185307179586 / hitbox_detail
        local cosine, sine = math.cos(angle), math.sin(angle)
        local x, y, visible = project_world(cx + ux * cosine + vx * sine,
            cy + uy * cosine + vy * sine, cz + uz * cosine + vz * sine)
        if i == 0 then first_x, first_y, first_visible = x, y, visible end
        if hitbox_style == 1 and i > 0 and previous_visible and visible then
            overlay.edge(previous_x, previous_y, x, y, 255, 48, 48, 255)
        elseif hitbox_style == 0 and visible then
            overlay.rect(x - 1, y - 1, 3, 3, 255, 48, 48, 255)
        end
        previous_x, previous_y, previous_visible = x, y, visible
    end
    if hitbox_style == 1 and previous_visible and first_visible then
        overlay.edge(previous_x, previous_y, first_x, first_y, 255, 48, 48, 255)
    end
end

local function draw_sphere(x, y, z, radius)
    draw_world_ring(x, y, z, radius, 0, 0, 0, radius, 0)
    draw_world_ring(x, y, z, radius, 0, 0, 0, 0, radius)
    draw_world_ring(x, y, z, 0, radius, 0, 0, 0, radius)
end

local function draw_capsule(ax, ay, az, bx, by, bz, radius)
    local dx, dy, dz = bx - ax, by - ay, bz - az
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 0.001 then draw_sphere(ax, ay, az, radius) return end
    local nx, ny, nz = dx / length, dy / length, dz / length
    local ux, uy, uz
    if math.abs(ny) < 0.9 then
        ux, uy, uz = -nz, 0, nx
    else
        ux, uy, uz = 0, nz, -ny
    end
    local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
    ux, uy, uz = ux / ul, uy / ul, uz / ul
    local vx, vy, vz = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
    ux, uy, uz, vx, vy, vz = ux * radius, uy * radius, uz * radius,
        vx * radius, vy * radius, vz * radius
    local wx, wy, wz = nx * radius, ny * radius, nz * radius
    draw_world_ring(ax, ay, az, ux, uy, uz, vx, vy, vz)
    draw_world_ring(bx, by, bz, ux, uy, uz, vx, vy, vz)
    draw_world_ring(ax, ay, az, wx, wy, wz, ux, uy, uz)
    draw_world_ring(ax, ay, az, wx, wy, wz, vx, vy, vz)
    draw_world_ring(bx, by, bz, wx, wy, wz, ux, uy, uz)
    draw_world_ring(bx, by, bz, wx, wy, wz, vx, vy, vz)
    for i = 0, hitbox_detail - 1 do
        local angle = i * 6.283185307179586 / hitbox_detail
        local cosine, sine = math.cos(angle), math.sin(angle)
        local ox, oy, oz = ux * cosine + vx * sine, uy * cosine + vy * sine, uz * cosine + vz * sine
        local x0, y0, v0 = project_world(ax + ox, ay + oy, az + oz)
        local x1, y1, v1 = project_world(bx + ox, by + oy, bz + oz)
        if hitbox_style == 1 and v0 and v1 then
            overlay.edge(x0, y0, x1, y1, 255, 48, 48, 255)
        elseif hitbox_style == 0 then
            if v0 then overlay.rect(x0 - 1, y0 - 1, 3, 3, 255, 48, 48, 255) end
            if v1 then overlay.rect(x1 - 1, y1 - 1, 3, 3, 255, 48, 48, 255) end
        end
    end
end

local function draw_hitbox()
    if builder_generation == 0 or (hitbox_type ~= 0 and hitbox_type ~= 1) then return false end
    local data = variant.builder_capture_state + 8
    local ax, ay, az = memory.read_float(data + 0x10), memory.read_float(data + 0x14),
        memory.read_float(data + 0x18)
    local asx, asy, av = project_world(ax, ay, az)
    if not av or hitbox_radius <= 0 or hitbox_radius > 100000 then return false end

    overlay.rect(asx - 2, asy - 2, 5, 5, 255, 255, 32, 255)
    if hitbox_type == 0 then
        local bx, by, bz = memory.read_float(data + 0x20), memory.read_float(data + 0x24),
            memory.read_float(data + 0x28)
        local bsx, bsy, bv = project_world(bx, by, bz)
        if bv then
            overlay.rect(bsx - 2, bsy - 2, 5, 5, 255, 255, 32, 255)
            draw_capsule(ax, ay, az, bx, by, bz, hitbox_radius)
        end
    else
        draw_sphere(ax, ay, az, hitbox_radius)
    end
    return true
end

local function draw_shape_diagnostic()
    if builder_generation == 0 then return end
    local address = hitbox_descriptor
    if not valid_pointer(address) then return end
    local ax = memory.read_float(address + 0x10)
    local ay = memory.read_float(address + 0x14)
    local az = memory.read_float(address + 0x18)
    local text
    if hitbox_type == 0 then
        local bx = memory.read_float(address + 0x1C)
        local by = memory.read_float(address + 0x20)
        local bz = memory.read_float(address + 0x24)
        text = string.format("%08X %.1f,%.1f,%.1f|%.1f/%.1f,%.1f,%.1f|%.1f",
            address, ax, ay, az, hitbox_radius, bx, by, bz, hitbox_radius)
    elseif hitbox_type == 1 then
        text = string.format("%08X %.1f,%.1f,%.1f|%.1f", address, ax, ay, az, hitbox_radius)
    else
        return
    end
    overlay.text(text, 8, 8, 1, 255, 220, 40, 255)
end

local function scan_hitbox_builder()
    if builder_address ~= 0 or not variant.hitbox_scan_start then return end
    if builder_scan_cursor < variant.hitbox_scan_start or builder_scan_cursor >= variant.hitbox_scan_end then
        builder_scan_cursor = variant.hitbox_scan_start
    end

    local scan_end = builder_scan_cursor + 0x400
    if scan_end > variant.hitbox_scan_end then scan_end = variant.hitbox_scan_end end
    local address = builder_scan_cursor
    while address + 8 < scan_end do
        if memory.read32(address) == 0xC4800220
            and memory.read32(address + 4) == 0xC4A1000C
            and memory.read32(address + 8) == 0x3C0B3F80 then
            builder_address = address + 4
            builder_saved = pcall(memory.dump, root .. "dumps/hitbox_builder_runtime.bin",
                address - 0x100, 0x400)
            result_line = builder_saved
                and string.format("BUILDER %08X SAVED", builder_address)
                or string.format("BUILDER %08X DUMP ERROR", builder_address)
            message = result_line
            return
        end
        address = address + 4
    end

    builder_scan_cursor = scan_end
    if builder_scan_cursor >= variant.hitbox_scan_end then builder_scan_cursor = variant.hitbox_scan_start end
    result_line = string.format("BUILDER SCAN %08X", builder_scan_cursor)
end

local function install_builder_capture()
    if builder_address == 0 or builder_hooked then return end
    local return_address = builder_address + 0xE0
    local instruction = memory.read32(return_address)
    if instruction ~= 0x03E00008 and instruction ~= variant.builder_capture_jump then
        result_line = string.format("RETURN MISMATCH %08X", instruction)
        return
    end
    mods.load_bin(root .. "bins/" .. variant.builder_capture_bin[1], variant.builder_capture_bin[2])
    memory.write32(variant.builder_capture_state, 0)
    if instruction == 0x03E00008 then
        mods.hook32(id, return_address, variant.builder_capture_jump, 0x03E00008)
    end
    local entry_address = builder_address - 0xD0
    local entry_instruction = memory.read32(entry_address)
    if entry_instruction ~= 0x27BDFFC0 and entry_instruction ~= variant.builder_entry_jump then
        result_line = string.format("ENTRY MISMATCH %08X", entry_instruction)
        return
    end
    local resume_address = entry_address + 8
    local resume_jump = 0x08000000 + math.floor((resume_address % 0x10000000) / 4)
    mods.hook32(id, variant.builder_entry_return_slot, resume_jump, 0)
    if entry_instruction == 0x27BDFFC0 then
        mods.hook32(id, entry_address, variant.builder_entry_jump, 0x27BDFFC0)
    end
    builder_hooked = true
    result_line = string.format("CAPTURE HOOK %08X", return_address)
end

local function update_builder_capture()
    if not builder_hooked then return end
    local generation = memory.read32(variant.builder_capture_state)
    if generation == builder_generation then return end
    builder_generation = generation
    local data = variant.builder_capture_state + 8
    hitbox_type = memory.read32(data)
    hitbox_owner = memory.read32(variant.builder_capture_state + 0x48)
    hitbox_descriptor = memory.read32(variant.builder_capture_state + 0x4C)
    if hitbox_type == 0 then
        hitbox_radius = memory.read_float(data + 0x30)
    elseif hitbox_type == 1 then
        hitbox_radius = memory.read_float(data + 0x20)
    else
        hitbox_radius = 0
    end
    status_line = string.format("SHAPE %d TYPE %d OWNER %08X", generation, hitbox_type, hitbox_owner)
    result_line = string.format("RADIUS %.2f SOURCE %08X", hitbox_radius,
        memory.read32(variant.builder_capture_state + 4))
end

local function install()
    local instruction = memory.read32(variant.hook[1])
    if instruction ~= variant.expected and instruction ~= variant.hook[2] then
        message = string.format("CAPTURE POINT BUSY %08X", instruction)
        return false
    end
    mods.load_bin(root .. "bins/" .. variant.bin[1], variant.bin[2])
    if instruction == variant.expected then
        mods.hook32(id, variant.hook[1], variant.hook[2], variant.expected)
    end
    mods.load_bin(root .. "bins/" .. variant.copy_matrix_bin, variant.copy_matrix_address)
    if memory.read32(variant.matrix_hook[1]) ~= variant.matrix_hook[2] then
        mods.hook32(id, variant.matrix_hook[1], variant.matrix_hook[2])
    end
    memory.write32(variant.state, 0)
    memory.write32(variant.state + 4, 0)
    memory.write32(variant.node_table, 0)
    installed = true
    message, status_line = "READY - HIT A MONSTER", "STATE WAITING FOR HIT"
    return true
end

function mod.enable()
    if not variant then error("unsupported game") end
    enabled, installed, skeleton_built = true, false, false
    last_generation, monster_address = 0, 0
    bones_found, bones_visible = 0, 0
    result_line = "DAMAGE PATH WAITING"
    builder_address, builder_saved, builder_hooked = 0, false, false
    builder_generation, hitbox_type, hitbox_radius = 0, -1, 0
    hitbox_owner, hitbox_descriptor = 0, 0
    builder_scan_cursor = variant.hitbox_scan_start or 0
    message, status_line = "INSTALLING", "STATE INSTALLING"
end

function mod.disable()
    mods.disable(id)
    enabled, installed = false, false
    message = "DIAGNOSTICS DISABLED"
end

function mod.update()
    if not enabled or not variant then return end
    if not installed and not install() then return end
    if memory.read32(variant.matrix_hook[1]) ~= variant.matrix_hook[2] then
        mods.load_bin(root .. "bins/" .. variant.copy_matrix_bin, variant.copy_matrix_address)
        mods.hook32(id, variant.matrix_hook[1], variant.matrix_hook[2])
    end
    scan_hitbox_builder()
    install_builder_capture()
    update_builder_capture()
    local generation = memory.read32(variant.state + 4)
    if generation == last_generation then return end
    last_generation = generation
    local previous_monster = monster_address
    monster_address = memory.read32(variant.state + 0x14)
    if valid_pointer(monster_address) then
        if monster_address ~= previous_monster and builder_hooked then
            memory.write32(variant.builder_capture_state, 0)
            builder_generation, hitbox_type, hitbox_radius = 0, -1, 0
            hitbox_owner, hitbox_descriptor = 0, 0
        end
        build_node_table()
        message = string.format("HIT %d - %d BONES", generation, bones_found)
    else
        skeleton_built, bones_found = false, 0
        status_line = string.format("BAD MONSTER POINTER %08X", monster_address)
    end
end

function mod.draw()
    if not enabled then return end
    bones_visible = 0
    if builder_hooked then
        draw_hitbox()
        draw_shape_diagnostic()
    end
    if skeleton_built and not builder_hooked then
        local count = memory.read32(variant.node_table)
        if count > bone_limit then count = bone_limit end
        if count > 48 then count = 48 end
        for i = 0, count - 1 do
            local node = memory.read32(variant.node_table + 4 + i * 8)
            local sx, sy, visible = project(node)
            local output = variant.screen_data + i * 12
            memory.write32(output, sx)
            memory.write32(output + 4, sy)
            memory.write32(output + 8, visible and 1 or 0)
            if visible then bones_visible = bones_visible + 1 end
        end
        for i = 0, count - 1 do
            local output = variant.screen_data + i * 12
            if memory.read32(output + 8) ~= 0 then
                local sx, sy = memory.read32(output), memory.read32(output + 4)
                overlay.rect(sx - 1, sy - 1, 3, 3, 255, 64, 64, 255)
                local parent = memory.read32(variant.node_table + 8 + i * 8)
                if parent < count then
                    local parent_output = variant.screen_data + parent * 12
                    if memory.read32(parent_output + 8) ~= 0 then
                        draw_safe_line(memory.read32(parent_output), memory.read32(parent_output + 4), sx, sy)
                    end
                end
            end
        end
    end
    if builder_hooked then return end
    if bones_visible == 0 then
        overlay.text("HITBOX DIAGNOSTICS", 8, 8, 1, 255, 220, 40, 255)
        overlay.text(status_line, 8, 20, 1, 255, 255, 255, 255)
        overlay.text(string.format("BONES %d VISIBLE %d LIMIT %d", bones_found, bones_visible, bone_limit),
            8, 32, 1, 255, 255, 255, 255)
        overlay.text(result_line, 8, 44, 1, 80, 220, 255, 255)
    end
end

mod.settings = {
    {
        name = "BONES TO DRAW", min = 1, max = 48,
        get = function() return bone_limit end,
        set = function(value)
            bone_limit = value
            status_line = string.format("READY BONES %d LIMIT %d", bones_found, bone_limit)
        end
    },
    {
        name = "HITBOX DETAIL", min = 4, max = 24,
        get = function() return hitbox_detail end,
        set = function(value) hitbox_detail = value end
    },
    {
        name = "HITBOX STYLE", min = 0, max = 1,
        get = function() return hitbox_style end,
        set = function(value) hitbox_style = value end
    }
}

return mod
